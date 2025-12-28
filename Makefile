.PHONY: help preprocessing preprocessing-build preprocessing-shell preprocessing-clean preprocessing-example finetune finetune-shell finetune-clean gradio gradio-shell gradio-clean

# Detect Docker Compose command (v1 vs v2)
DOCKER_COMPOSE := $(shell command -v docker-compose 2> /dev/null)
ifndef DOCKER_COMPOSE
	DOCKER_COMPOSE := docker compose
endif

# Default target
help:
	@echo "Hunyuan3D-2.1 Makefile"
	@echo ""
	@echo "Preprocessing targets:"
	@echo "  make preprocessing              - Run preprocessing pipeline (interactive)"
	@echo "  make preprocessing-build        - Build preprocessing Docker image"
	@echo "  make preprocessing-shell        - Open shell in preprocessing container"
	@echo "  make preprocessing-clean        - Remove preprocessing container and image"
	@echo "  make preprocessing-example      - Run example preprocessing on sample data"
	@echo ""
	@echo "Fine-tuning targets:"
	@echo "  make finetune                   - Start fine-tuning with custom config"
	@echo "  make finetune-shell             - Open shell in fine-tuning container"
	@echo "  make finetune-clean             - Stop and remove fine-tuning container"
	@echo ""
	@echo "Gradio Demo targets:"
	@echo "  make gradio                     - Start Gradio web interface (http://localhost:7860)"
	@echo "  make gradio-shell               - Open shell in Gradio container"
	@echo "  make gradio-clean               - Stop and remove Gradio container"
	@echo ""
	@echo "Data directories:"
	@echo "  src/preprocessing/data/raw/        - Input .obj/.glb files"
	@echo "  src/preprocessing/data/preprocessed/ - Preprocessed training data"
	@echo "  output/                            - Training checkpoints and logs"

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

# Fine-tuning targets
finetune-shell:
	@echo "Starting fine-tuning container shell..."
	@if ! docker images | grep -q hunyuan3d21; then \
		echo "Error: Docker image 'hunyuan3d21:latest' not found!"; \
		echo "Please build the image first using the main Dockerfile."; \
		exit 1; \
	fi
	$(DOCKER_COMPOSE) -f docker-compose.finetuning.yaml run --rm finetuning

finetune:
	@echo "Starting fine-tuning with custom config..."
	@if ! docker images | grep -q hunyuan3d21; then \
		echo "Error: Docker image 'hunyuan3d21:latest' not found!"; \
		echo "Please build the image first using the main Dockerfile."; \
		exit 1; \
	fi
	@if [ ! -d "src/preprocessing/data/preprocessed" ] || [ -z "$$(ls -A src/preprocessing/data/preprocessed 2>/dev/null)" ]; then \
		echo "Error: No preprocessed data found!"; \
		echo "Please run 'make preprocessing-example' first to preprocess your data."; \
		exit 1; \
	fi
	@mkdir -p output
	@echo ""
	@echo "========================================="
	@echo "Starting fine-tuning session"
	@echo "========================================="
	@echo "Config: /workspace/finetuning/hunyuan3d-custom-finetuning.yaml"
	@echo "Data: /workspace/data/preprocessed"
	@echo "Output: /workspace/output"
	@echo "========================================="
	@echo ""
	@echo "Run this command inside the container:"
	@echo "  python main.py -c /workspace/finetuning/hunyuan3d-custom-finetuning.yaml --output_dir /workspace/output/custom-finetune --num_gpus 8 --num_nodes 1"
	@echo ""
	$(DOCKER_COMPOSE) -f docker-compose.finetuning.yaml run --rm finetuning

finetune-clean:
	@echo "Cleaning up fine-tuning container..."
	$(DOCKER_COMPOSE) -f docker-compose.finetuning.yaml down -v

# Gradio Demo targets
gradio:
	@echo "Starting Gradio web interface..."
	@if ! docker images | grep -q hunyuan3d21; then \
		echo "Error: Docker image 'hunyuan3d21:latest' not found!"; \
		echo "Please build the image first using the main Dockerfile."; \
		exit 1; \
	fi
	@echo ""
	@echo "========================================="
	@echo "Starting Gradio Demo"
	@echo "========================================="
	@echo "Image: hunyuan3d21:latest"
	@echo "Web Interface: http://localhost:7860"
	@echo "Models cached in: ~/.cache/huggingface"
	@echo "========================================="
	@echo ""
	@echo "Starting container..."
	$(DOCKER_COMPOSE) -f docker-compose.gradio.yaml up

gradio-shell:
	@echo "Starting Gradio container shell..."
	@if ! docker images | grep -q hunyuan3d21; then \
		echo "Error: Docker image 'hunyuan3d21:latest' not found!"; \
		echo "Please build the image first using the main Dockerfile."; \
		exit 1; \
	fi
	$(DOCKER_COMPOSE) -f docker-compose.gradio.yaml run --rm --entrypoint /bin/bash gradio

gradio-clean:
	@echo "Cleaning up Gradio container..."
	$(DOCKER_COMPOSE) -f docker-compose.gradio.yaml down -v
