import { NodeTracerProvider, SimpleSpanProcessor } from '@opentelemetry/sdk-trace-node';
import { TraceExporter } from '@google-cloud/opentelemetry-cloud-trace-exporter';
import { Resource } from '@opentelemetry/resources';
import { SEMRESATTRS_SERVICE_NAME } from '@opentelemetry/semantic-conventions';
import { trace } from '@opentelemetry/api';

const serviceName = process.env.SERVICE_NAME || 'analytics-worker';
const projectId = process.env.PROJECT_ID;

const provider = new NodeTracerProvider({
  resource: new Resource({
    [SEMRESATTRS_SERVICE_NAME]: serviceName,
  }),
});

try {
  const exporter = new TraceExporter({ projectId });
  provider.addSpanProcessor(new SimpleSpanProcessor(exporter));
  console.log(`Cloud Trace Exporter initialized for worker: ${serviceName}, project: ${projectId}`);
} catch (err) {
  console.warn('Could not initialize Cloud Trace exporter, tracing locally only:', err);
}

provider.register();

export const tracer = trace.getTracer(serviceName);

export function getTraceContext(): { traceId?: string; spanId?: string; isSampled?: boolean } {
  const activeSpan = trace.getActiveSpan();
  if (!activeSpan) return {};
  const spanContext = activeSpan.spanContext();
  return {
    traceId: spanContext.traceId,
    spanId: spanContext.spanId,
    isSampled: spanContext.traceFlags === 1,
  };
}

export function logStructured(
  severity: 'DEFAULT' | 'DEBUG' | 'INFO' | 'NOTICE' | 'WARNING' | 'ERROR' | 'CRITICAL',
  message: string,
  extra: Record<string, any> = {}
) {
  const { traceId, spanId, isSampled } = getTraceContext();
  const entry: Record<string, any> = {
    severity,
    message,
    timestamp: new Date().toISOString(),
    service: serviceName,
    ...extra,
  };

  if (traceId && projectId) {
    entry['logging.googleapis.com/trace'] = `projects/${projectId}/traces/${traceId}`;
    if (spanId) {
      entry['logging.googleapis.com/spanId'] = spanId;
    }
    entry['logging.googleapis.com/trace_sampled'] = isSampled ?? true;
  }

  process.stdout.write(JSON.stringify(entry) + '\n');
}
