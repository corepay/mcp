FROM python:3.11-slim

WORKDIR /app

# Install system dependencies for Docling, OpenCV, and Tesseract
# Docling needs: build-essential for some deps
# OpenCV needs: libgl1, libglib2.0-0
# Tesseract is optional but recommended for OCR fallback
RUN apt-get update && apt-get install -y \
    build-essential \
    libgl1 \
    libglib2.0-0 \
    tesseract-ocr \
    pkg-config \
    poppler-utils \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .

# Upgrade pip and install dependencies
# We install pytorch CPU version to keep image size reasonable if no GPU is available,
# but Docling usually pulls it automatically. explicit install helps control version.
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

COPY . .

# Expose port
EXPOSE 8000

# Start the application
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
