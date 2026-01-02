# Risk Model Sidecar

ML-based risk scoring service for underwriting.

## Setup

```bash
cd apps/risk_model
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

## Run

```bash
uvicorn app:app --port 48292
```

Or with auto-reload for development:
```bash
uvicorn app:app --port 48292 --reload
```

## API

- `GET /health` - Health check
- `POST /predict` - Get risk prediction
- `GET /models` - List available models

### Predict Request

```json
{
  "features": {
    "business_years": 5,
    "monthly_volume": 50000,
    "mcc": 5411
  },
  "model_name": "default"
}
```

### Predict Response

```json
{
  "score": 75.0,
  "confidence": 0.85,
  "risk_factors": ["New business (< 1 year)"],
  "recommendation": "manual_review"
}
```

## Training

Models are trained offline and placed in `models/` directory as `.pkl` files.
See `training/` for training notebooks.

## Fallback Behavior

When no ML model is loaded, the service uses rule-based scoring:
- Base score: 50
- Business age: +15 (5+ years), +10 (2+ years), -10 (< 1 year)
- Volume: +10 ($50k+), -5 (< $10k)
- High-risk MCC: -20
