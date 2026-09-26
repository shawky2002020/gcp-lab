import './tracer'; // Initialize tracer before anything else
import express, { Request, Response } from 'express';
import { BigQuery } from '@google-cloud/bigquery';
import { context, propagation, trace } from '@opentelemetry/api';
import { tracer, logStructured, getTraceContext } from './tracer';

const app = express();
app.use(express.json());

const port = process.env.PORT || 8080;
const projectId = process.env.PROJECT_ID || 'bq-observe-lab-840614';
const datasetId = process.env.DATASET_ID || 'analytics_lab';
const tableId = process.env.TABLE_ID || 'order_events';

const bigquery = new BigQuery({ projectId });

// Health check endpoint
app.get('/health', (req: Request, res: Response) => {
  res.status(200).json({ status: 'ok', service: 'analytics-worker', timestamp: new Date().toISOString() });
});

// Pub/Sub Push Handler
app.post('/', async (req: Request, res: Response): Promise<void> => {
  if (!req.body || !req.body.message) {
    logStructured('WARNING', 'Received invalid Pub/Sub push payload (no message object)', { body: req.body });
    res.status(400).send('Bad Request: Invalid Pub/Sub message format');
    return;
  }

  const pubsubMessage = req.body.message;
  const attributes = pubsubMessage.attributes || {};

  // Extract W3C Trace Context propagated from order-api
  const parentContext = propagation.extract(context.active(), attributes);

  const workerSpan = tracer.startSpan('analytics-worker.process-order', {}, parentContext);

  await context.with(trace.setSpan(parentContext, workerSpan), async () => {
    try {
      const { traceId } = getTraceContext();
      const messageId = pubsubMessage.messageId;
      const rawData = Buffer.from(pubsubMessage.data, 'base64').toString('utf-8');
      const event = JSON.parse(rawData);

      workerSpan.setAttributes({
        'pubsub.message_id': messageId,
        'order.id': event.orderId || 'unknown',
        'order.user_id': event.userId || 'unknown',
        'order.event_id': event.eventId || 'unknown',
      });

      logStructured('INFO', 'Received and decoded Pub/Sub message', {
        messageId,
        eventId: event.eventId,
        orderId: event.orderId,
        userId: event.userId,
      });

      // Controlled failure simulation for Section 23 / testing retries
      if (event.userId === 'fail-test' || event.testFail === true) {
        logStructured('ERROR', 'Simulating worker processing failure for controlled retry lab', {
          eventId: event.eventId,
          orderId: event.orderId,
          reason: 'Intentional failure trigger detected in payload',
        });
        workerSpan.setStatus({ code: 2, message: 'Intentional failure simulation' });
        workerSpan.end();
        // Return 500 so Pub/Sub does not ACK and will retry according to subscription policy
        res.status(500).send('Intentional failure simulation: message will be retried by Pub/Sub');
        return;
      }

      // Prepare BigQuery row
      const row = {
        event_id: event.eventId,
        event_type: event.type || 'order.created',
        order_id: event.orderId,
        user_id: event.userId,
        amount: event.amount,
        status: event.status || 'created',
        source: 'order-api',
        created_at: event.createdAt || new Date().toISOString(),
        processed_at: new Date().toISOString(),
        trace_id: traceId || null,
      };

      // Child span for BigQuery write
      const bqSpan = tracer.startSpan('analytics-worker.bigquery-insert', {}, context.active());
      bqSpan.setAttribute('bigquery.table', `${projectId}.${datasetId}.${tableId}`);

      try {
        await bigquery
          .dataset(datasetId)
          .table(tableId)
          .insert([row]);
        bqSpan.end();
      } catch (insertErr: any) {
        bqSpan.recordException(insertErr);
        bqSpan.setStatus({ code: 2, message: insertErr.message });
        bqSpan.end();
        throw insertErr;
      }

      logStructured('INFO', 'Order event successfully inserted into BigQuery', {
        eventId: event.eventId,
        orderId: event.orderId,
        userId: event.userId,
        amount: event.amount,
        bqTable: `${datasetId}.${tableId}`,
      });

      workerSpan.end();

      // Return 200/204 to ACK the message to Pub/Sub
      res.status(200).send('OK');
    } catch (err: any) {
      logStructured('ERROR', 'Failed to process Pub/Sub message in analytics-worker', {
        error: err.message,
        stack: err.stack,
        details: err.errors || null,
      });
      workerSpan.recordException(err);
      workerSpan.setStatus({ code: 2, message: err.message });
      workerSpan.end();
      res.status(500).send(`Processing Error: ${err.message}`);
    }
  });
});

app.listen(port, () => {
  logStructured('INFO', `analytics-worker listening on port ${port}`, {
    port,
    projectId,
    datasetId,
    tableId,
  });
});
