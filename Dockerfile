# Base image for Python
FROM python:3.9-slim

# Set the working directory
WORKDIR /app

# Copy the requirements.txt
COPY requirements.txt /app/requirements.txt

# Install required dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy MkDocs project files
COPY . /app

# Build the MkDocs static site
RUN mkdocs build

# Serve the static site using a lightweight HTTP server
RUN pip install httpserver

# Define the static site directory as the working directory
WORKDIR /app/site

# Expose port 8000
EXPOSE 8000

# Serve using Python's built-in server
CMD ["python3", "-m", "http.server", "8000"]