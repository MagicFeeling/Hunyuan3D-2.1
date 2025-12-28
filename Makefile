.PHONY: help preprocessing preprocessing-build preprocessing-shell preprocessing-clean preprocessing-example

# Detect Docker Compose command (v1 vs v2)
DOCKER_COMPOSE := $(shell command -v docker-compose 2> /dev/null)
ifndef DOCKER_COMPOSE
	DOCKER_COMPOSE := docker compose
endif

# Default target
help:
	@echo "Hunyuan3D-2.1 Makefile"
	@echo ""
	@echo "Available targets:"
	@echo "  make preprocessing              - Run preprocessing pipeline (interactive)"
	@echo "  make preprocessing-build        - Build preprocessing Docker image"
	@echo "  make preprocessing-shell        - Open shell in preprocessing container"
	@echo "  make preprocessing-clean        - Remove preprocessing container and image"
	@echo "  make preprocessing-example      - Run example preprocessing on sample data"
	@echo ""
	@echo "Before running, ensure your data is placed in:"
	@echo "  src/preprocessing/data/raw/        - Input .obj/.glb files"
	@echo "  src/preprocessing/data/preprocessed/ - Output will be saved here"

# Build the preprocessing Docker image
preprocessing-build:
	@echo "Building preprocessing Docker image..."
	$(DOCKER_COMPOSE) -f docker-compose.preprocessing.yaml build

# Start preprocessing container and open shell
preprocessing-shell: preprocessing-build
	@echo "Starting preprocessing container..."
	$(DOCKER_COMPOSE) -f docker-compose.preprocessing.yaml run --rm preprocessing

# Run preprocessing pipeline (interactive mode)
preprocessing: preprocessing-build
	@echo "Starting preprocessing pipeline..."
	@echo "You will be dropped into a shell. Run your preprocessing commands there."
	@echo ""
	@echo "Example commands:"
	@echo "  cd /workspace/tools"
	@echo "  bash scripts/preprocess_single.sh /workspace/data/raw/your_model.obj your_model_name"
	@echo ""
	$(DOCKER_COMPOSE) -f docker-compose.preprocessing.yaml run --rm preprocessing

# Clean up preprocessing containers and images
preprocessing-clean:
	@echo "Cleaning up preprocessing containers and images..."
	$(DOCKER_COMPOSE) -f docker-compose.preprocessing.yaml down -v
	docker rmi hunyuan3d-preprocessing:latest || true

# Run example preprocessing
preprocessing-example: preprocessing-build
	@echo "Running example preprocessing..."
	@if [ ! -d "src/preprocessing/data/raw" ]; then \
		echo "Error: src/preprocessing/data/raw directory not found!"; \
		echo "Please create it and place your .obj files there."; \
		exit 1; \
	fi
	@if [ -z "$$(ls -A src/preprocessing/data/raw/*.obj 2>/dev/null)" ] && [ -z "$$(ls -A src/preprocessing/data/raw/*.glb 2>/dev/null)" ]; then \
		echo "Error: No .obj or .glb files found in src/preprocessing/data/raw/"; \
		echo "Please place your 3D model files there first."; \
		exit 1; \
	fi
	$(DOCKER_COMPOSE) -f docker-compose.preprocessing.yaml run --rm preprocessing \
		bash -c "cd /workspace/tools && bash scripts/preprocess_batch.sh /workspace/data/raw /workspace/data/preprocessed"
