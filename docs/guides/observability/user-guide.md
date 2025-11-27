# Observability User Guide

## Overview
This guide is for Operations teams and Developers monitoring the production environment.

## Monitoring Dashboards
(Future: Links to Grafana / Datadog dashboards will go here)

## Alerting
Alerts are configured for the following critical conditions:
- **High Error Rate**: > 1% of requests failing for 5 minutes.
- **High Latency**: p95 response time > 500ms for 5 minutes.
- **Database Load**: CPU > 80% for 10 minutes.

## Incident Response
If an alert triggers:
1.  **Check Logs**: Look for recent exceptions or error patterns.
2.  **Check Database**: Use `mix db.analyze` on slow queries if database load is high.
3.  **Scale**: If saturation is high, consider scaling up resources (if auto-scaling is not enabled).
