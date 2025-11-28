from fastapi import FastAPI, UploadFile, File, HTTPException
from pydantic import BaseModel
import uvicorn
import os
import tempfile
import shutil

app = FastAPI(title="The Eye - Document Intelligence Service")

class AnalysisResponse(BaseModel):
    status: str
    markdown_content: str | None = None
    structured_data: dict | None = None
    provider: str

@app.get("/health")
def health_check():
    return {"status": "healthy"}

@app.post("/analyze/document", response_model=AnalysisResponse)
async def analyze_document(file: UploadFile = File(...)):
    # Create a temporary file to save the uploaded content
    with tempfile.NamedTemporaryFile(delete=False, suffix=os.path.splitext(file.filename)[1]) as tmp_file:
        shutil.copyfileobj(file.file, tmp_file)
        tmp_path = tmp_file.name

    try:
        # TODO: Implement actual Marker/Chandra logic here
        # For now, we will return a mock response to verify connectivity
        
        # Mock logic:
        # If it's a PDF, pretend we used Marker
        if file.filename.lower().endswith(".pdf"):
            return AnalysisResponse(
                status="success",
                markdown_content="# Bank Statement\n\n| Date | Description | Amount |\n|---|---|---|\n| 2023-10-01 | Deposit | $5000.00 |",
                provider="marker"
            )
        # If it's an image, pretend we used Chandra
        else:
             return AnalysisResponse(
                status="success",
                structured_data={"form_type": "check", "amount": 100.00},
                provider="chandra"
            )

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        # Clean up the temporary file
        if os.path.exists(tmp_path):
            os.remove(tmp_path)

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
