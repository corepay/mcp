from fastapi import FastAPI, UploadFile, File, HTTPException
from pydantic import BaseModel
import uvicorn
import os
import tempfile
import shutil
import logging
from docling.document_converter import DocumentConverter, PdfFormatOption
from docling.datamodel.base_models import InputFormat
from docling.datamodel.pipeline_options import PdfPipelineOptions, TableStructureOptions

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("the_eye")

app = FastAPI(title="The Eye - Document Intelligence Service (Docling)")

# Global converter instance to avoid reloading models on every request
# docling handles thread safety internally usually, but for simple use case global is fine
converter = None

@app.on_event("startup")
async def startup_event():
    global converter
    logger.info("Initializing Docling DocumentConverter with Advanced Finance Options...")
    try:
        # Configure pipeline for high-fidelity table extraction (Underwriting use case)
        pipeline_options = PdfPipelineOptions()
        pipeline_options.do_ocr = True
        pipeline_options.do_table_structure = True
        pipeline_options.table_structure_options.do_cell_matching = True
        
        converter = DocumentConverter(
            format_options={
                InputFormat.PDF: PdfFormatOption(pipeline_options=pipeline_options)
            }
        )
        logger.info("Docling DocumentConverter initialized successfully.")
    except Exception as e:
        logger.error(f"Failed to initialize Docling: {e}")
        raise e

class AnalysisResponse(BaseModel):
    status: str
    markdown_content: str | None = None
    structured_data: dict | None = None
    provider: str

@app.get("/health")
def health_check():
    if converter:
        return {"status": "healthy", "provider": "docling"}
    else:
        raise HTTPException(status_code=503, detail="Docling not initialized")

@app.post("/analyze/document", response_model=AnalysisResponse)
async def analyze_document(file: UploadFile = File(...)):
    if not converter:
        raise HTTPException(status_code=503, detail="Service not ready")

    # Create a temporary file to save the uploaded content
    # Docling detects format by extension, so preserve it
    suffix = os.path.splitext(file.filename)[1]
    if not suffix:
        # Default to pdf if no extension? Or raise error?
        # Let's assume binary stream might be identifiable, but file extension is safest
        suffix = ""
    
    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp_file:
        shutil.copyfileobj(file.file, tmp_file)
        tmp_path = tmp_file.name

    try:
        logger.info(f"Processing file: {file.filename} ({tmp_path})")
        
        # Run Docling Conversion
        # This is CPU/GPU intensive and synchronous. In a real heavy load, 
        # this should be in a background thread/process or use async features if available.
        # For this sidecar implementation, we'll run it directly (FastAPI handles it in threadpool).
        
        result = converter.convert(tmp_path)
        
        # Export content
        markdown_text = result.document.export_to_markdown()
        
        # Serialize structured data
        # Docling's internal structure is complex. exporting to dict gives a representation.
        structured_dict = result.document.export_to_dict()

        return AnalysisResponse(
            status="success",
            markdown_content=markdown_text,
            structured_data=structured_dict,
            provider="docling"
        )

    except Exception as e:
        logger.error(f"Error processing document: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        # Clean up the temporary file
        if os.path.exists(tmp_path):
            os.remove(tmp_path)

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
