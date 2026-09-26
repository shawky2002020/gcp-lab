import './tracer'; // Initialize tracer before anything else
import express, { Request, Response } from 'express';
import { PubSub } from '@google-cloud/pubsub';
import { randomUUID } from 'crypto';
import { context, propagation, trace } from '@opentelemetry/api';
import { tracer, logStructured } from './tracer';

const app = express();
app.use(express.json());

const port = process.env.PORT || 8080;
const topicName = process.env.TOPIC_NAME || 'order-events';
const projectId = process.env.PROJECT_ID || 'bq-observe-lab-840614';

const pubsub = new PubSub({ projectId });
const topic = pubsub.topic(topicName);

// Health check endpoint
app.get('/health', (req: Request, res: Response) => {
  res.status(200).json({ status: 'ok', service: 'order-api', timestamp: new Date().toISOString() });
});

// Controlled slow request endpoint for latency inspection in Cloud Trace / Cloud Monitoring
app.get('/slow', async (req: Request, res: Response) => {
  const delayMs = parseInt(req.query.ms as string, 10) || 800;
  const span = tracer.startSpan('controlled-slow-request');

  await context.with(trace.setSpan(context.active(), span), async () => {
    logStructured('INFO', `Simulating slow request of ${delayMs}ms`, { delayMs });
    await new Promise((resolve) => setTimeout(resolve, delayMs));
    span.setAttribute('delay_ms', delayMs);
    span.end();
  });

  res.status(200).json({ status: 'completed', delayMs, message: `Finished after ${delayMs}ms delay` });
});

// Controlled error endpoint to verify Cloud Logging error ingestion, metrics, and alerting
app.get('/test-error', (req: Request, res: Response) => {
  const span = tracer.startSpan('controlled-test-error');
  context.with(trace.setSpan(context.active(), span), () => {
    const errorDetails = {
      errorType: 'IntentionalLabError',
      reason: 'Controlled test error for Cloud Monitoring alert policy verification',
      code: 500,
    };
    logStructured('ERROR', 'Controlled lab error generated for observability testing', errorDetails);
    span.recordException(new Error('Controlled lab test error'));
    span.setStatus({ code: 2, message: 'Intentional failure' }); // 2 = ERROR in OTel
    span.end();
  });

  res.status(500).json({
    status: 'error',
    message: 'Controlled test error generated successfully. Inspect in Cloud Logging and Cloud Monitoring.',
  });
});

// Primary domain endpoint: POST /orders
app.post('/orders', async (req: Request, res: Response): Promise<void> => {
  const rootSpan = tracer.startSpan('order-api.process-order');

  await context.with(trace.setSpan(context.active(), rootSpan), async () => {
    try {
      const { userId, amount } = req.body;

      if (!userId || typeof userId !== 'string') {
        res.status(400).json({ error: 'userId is required and must be a string' });
        rootSpan.end();
        return;
      }

      const parsedAmount = Number(amount);
      if (isNaN(parsedAmount) || parsedAmount <= 0) {
        res.status(400).json({ error: 'amount must be a positive number' });
        rootSpan.end();
        return;
      }

      const orderId = `ord-${randomUUID().slice(0, 8)}`;
      const eventId = `evt-${randomUUID()}`;
      const now = new Date().toISOString();

      const event = {
        eventId,
        type: 'order.created',
        orderId,
        userId,
        amount: parsedAmount,
        status: 'created',
        createdAt: now,
      };

      rootSpan.setAttributes({
        'order.id': orderId,
        'order.user_id': userId,
        'order.amount': parsedAmount,
        'order.event_id': eventId,
      });

      // Child span for publishing to Pub/Sub
      const publishSpan = tracer.startSpan('order-api.pubsub-publish', {}, context.active());

      // Inject W3C Trace Context into message attributes
      const carrier: Record<string, string> = {};
      propagation.inject(trace.setSpan(context.active(), publishSpan), carrier);

      const dataBuffer = Buffer.from(JSON.stringify(event));

      const messageId = await topic.publishMessage({
        data: dataBuffer,
        attributes: {
          ...carrier,
          eventType: 'order.created',
          orderId,
          userId,
        },
      });

      publishSpan.setAttribute('pubsub.message_id', messageId);
      publishSpan.setAttribute('pubsub.topic', topicName);
      publishSpan.end();

      logStructured('INFO', 'Order event created and published to Pub/Sub', {
        eventId,
        orderId,
        userId,
        amount: parsedAmount,
        pubsubMessageId: messageId,
        topic: topicName,
      });

      rootSpan.end();

      res.status(202).json({
        status: 'accepted',
        orderId,
        eventId,
        pubsubMessageId: messageId,
        event,
      });
    } catch (err: any) {
      logStructured('ERROR', 'Failed to publish order event', { error: err.message, stack: err.stack });
      rootSpan.recordException(err);
      rootSpan.setStatus({ code: 2, message: err.message });
      rootSpan.end();
      res.status(500).json({ error: 'Internal server error while publishing order event' });
    }
  });
});

app.listen(port, () => {
  logStructured('INFO', `order-api listening on port ${port}`, { port, topicName, projectId });
});
