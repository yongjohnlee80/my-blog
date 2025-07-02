# Base image for Python
FROM python:3.9-slim

# Set the working directory
WORKDIR /app

# Install system dependencies, including git
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy the requirements.txt file
COPY requirements.txt /app/requirements.txt

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy MkDocs project files
COPY . /app

# Copy the MkDocs project files
COPY . /app

# Expose the default MkDocs port
EXPOSE 8000

# Build the site (optional, mainly for debugging during image creation but also useful if needed later)
RUN mkdocs build

# Run MkDocs server
CMD ["mkdocs", "serve", "-a", "0.0.0.0:8000"]
