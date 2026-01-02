"""
Risk Model Sidecar Service
Serves ML models for underwriting risk scoring.
"""
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import pickle
import os
from pathlib import Path

app = FastAPI(title="Risk Model Service", version="1.0.0")

# Model storage
MODELS = {}


class PredictionRequest(BaseModel):
    features: dict
    model_name: str = "default"


class PredictionResponse(BaseModel):
    score: float
    confidence: float
    risk_factors: list[str]
    recommendation: str


class ModelInfo(BaseModel):
    name: str
    version: str
    accuracy: float
    feature_count: int


@app.get("/health")
def health_check():
    return {"status": "healthy", "models_loaded": list(MODELS.keys())}


@app.post("/predict", response_model=PredictionResponse)
def predict(request: PredictionRequest):
    """Generate risk prediction from features."""
    model = MODELS.get(request.model_name)

    if not model:
        # Fallback to rule-based if no model
        return rule_based_prediction(request.features)

    try:
        # In production, transform features and run model
        score = model.predict_proba([list(request.features.values())])[0][1]
        return PredictionResponse(
            score=round(score * 100, 2),
            confidence=0.85,
            risk_factors=extract_risk_factors(request.features, model),
            recommendation=get_recommendation(score)
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/models", response_model=list[ModelInfo])
def list_models():
    """List available models."""
    return [
        ModelInfo(
            name=name,
            version="1.0.0",
            accuracy=0.92,
            feature_count=len(model.feature_names_in_) if hasattr(model, 'feature_names_in_') else 0
        )
        for name, model in MODELS.items()
    ]


def rule_based_prediction(features: dict) -> PredictionResponse:
    """Fallback rule-based scoring when no ML model available."""
    score = 50.0
    factors = []

    # Business age factor
    years = features.get("business_years", 0)
    if years >= 5:
        score += 15
    elif years >= 2:
        score += 10
    elif years < 1:
        score -= 10
        factors.append("New business (< 1 year)")

    # Volume factor
    volume = features.get("monthly_volume", 0)
    if volume >= 50000:
        score += 10
    elif volume < 10000:
        score -= 5
        factors.append("Low monthly volume")

    # Industry risk
    high_risk_mcc = [5966, 5967, 7995, 5816]  # Example high-risk MCCs
    if features.get("mcc") in high_risk_mcc:
        score -= 20
        factors.append("High-risk industry category")

    return PredictionResponse(
        score=max(0, min(100, score)),
        confidence=0.70,  # Lower confidence for rules
        risk_factors=factors,
        recommendation=get_recommendation(score / 100)
    )


def get_recommendation(score: float) -> str:
    if score >= 0.8:
        return "auto_approve"
    elif score >= 0.5:
        return "manual_review"
    else:
        return "decline"


def extract_risk_factors(features: dict, model) -> list[str]:
    """Extract top contributing risk factors from model."""
    # In production, use SHAP or feature importance
    return []


@app.on_event("startup")
def load_models():
    """Load trained models on startup."""
    model_dir = Path(os.getenv("MODEL_DIR", "models"))
    if model_dir.exists():
        for model_file in model_dir.glob("*.pkl"):
            with open(model_file, "rb") as f:
                MODELS[model_file.stem] = pickle.load(f)
    print(f"Loaded {len(MODELS)} models")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=int(os.getenv("PORT", "48292")))
