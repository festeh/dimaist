# Load environment variables from .env file
set dotenv-load

# Default recipe - show available commands
default:
    @just --list

# Run command with env vars from .env file
_run-with-env +cmd:
    @just _run-with-env-file frontend/.env {{cmd}}

# Run command with env vars from specified file
_run-with-env-file envfile +cmd:
    #!/usr/bin/env bash
    if [ ! -f {{envfile}} ]; then
        echo "ERROR: {{envfile}} file not found"
        echo "Please create {{envfile}} with BASE_URL and ASR_URL"
        exit 1
    fi
    echo "Loading env vars from {{envfile}}"
    cd frontend && {{cmd}} --dart-define-from-file=../{{envfile}}

run-linux:
    @just _run-with-env flutter run -d linux

# Run Linux app with local backend (starts backend automatically)
run-linux-local verbose="":
    #!/usr/bin/env bash
    set -e

    # Find available port in range 9200-9250
    PORT=""
    for p in $(seq 9200 9250); do
        if ! ss -tuln | grep -q ":$p "; then
            PORT=$p
            break
        fi
    done

    if [ -z "$PORT" ]; then
        echo "ERROR: No available port in range 9200-9250"
        exit 1
    fi

    VERBOSE_FLAG=""
    if [ "{{verbose}}" = "verbose" ]; then
        VERBOSE_FLAG="--verbose"
        echo "Starting backend on port $PORT with verbose logging..."
    else
        echo "Starting backend on port $PORT..."
    fi
    cd backend && go run . -port=$PORT $VERBOSE_FLAG &
    BACKEND_PID=$!

    # Wait for backend to start
    sleep 2

    # Create temp env file with local URL
    echo "BASE_URL=http://localhost:$PORT" > frontend/.env.local.tmp
    grep -v "^BASE_URL=" frontend/.env >> frontend/.env.local.tmp 2>/dev/null || true

    echo "Starting frontend with BASE_URL=http://localhost:$PORT"
    cd frontend && flutter run -d linux --dart-define-from-file=.env.local.tmp

    # Cleanup
    rm -f frontend/.env.local.tmp
    kill $BACKEND_PID 2>/dev/null || true

# Launch Android emulator
emulator:
    flutter emulators --launch Pixel_8_Pro

# Stop Android emulator
emulator-stop:
    adb emu kill

# Run the phone app with environment variables
run-phone:
    @just _run-with-env flutter run --flavor phone -t lib/main.dart

# Run the Wear OS app with environment variables
run-wear:
    @just _run-with-env flutter run --flavor wear -t lib/main_wear.dart

# Run flutter analyze
analyze:
    cd frontend && flutter analyze

# Run tests
test:
    cd frontend && flutter test

# Get dependencies
deps:
    cd frontend && flutter pub get

# Upgrade dependencies
upgrade:
    cd frontend && flutter pub upgrade

# Build APK for phone
build-phone:
    @just _run-with-env flutter build apk --flavor phone -t lib/main.dart

# Build APK for Wear OS
build-wear:
    @just _run-with-env flutter build apk --flavor wear -t lib/main_wear.dart

# Build Linux app for release
build-linux:
    @just _run-with-env flutter build linux --release -t lib/main.dart

# Build and install phone APK
install-phone:
    @just build-phone
    adb install frontend/build/app/outputs/flutter-apk/app-phone-release.apk

# Copy phone APK to pCloud (builds first if needed)
deploy-phone: build-phone
    cp frontend/build/app/outputs/flutter-apk/app-phone-release.apk ~/pCloudDrive/android-apps/dimaist/

# Clean build artifacts
clean:
    cd frontend && flutter clean

# =============================================================================
# Backend recipes
# =============================================================================

# Run backend server (default port 3000)
run-backend:
    cd backend && go run .

# Run backend server on custom port
run-backend-port port:
    cd backend && go run . -port={{port}}

# Build backend binary
build-backend:
    cd backend && go build -o dimaist .

# Run backend tests
test-backend:
    cd backend && go test ./...

# Get/tidy backend dependencies
deps-backend:
    cd backend && go mod tidy

# =============================================================================
# Release
# =============================================================================

# Create a GitHub release with phone APK
# Usage: just release 1.1.0
release version:
    #!/usr/bin/env bash
    set -e

    VERSION="{{version}}"

    echo "Building phone APK..."
    cd frontend && flutter build apk --flavor phone -t lib/main.dart --dart-define-from-file=.env

    APK_PATH="frontend/build/app/outputs/flutter-apk/app-phone-release.apk"

    if [ ! -f "$APK_PATH" ]; then
        echo "ERROR: APK not found at $APK_PATH"
        exit 1
    fi

    echo "Creating GitHub release v$VERSION..."
    gh release create "v$VERSION" \
        --title "v$VERSION" \
        --notes "" \
        "$APK_PATH#dimaist-phone-v$VERSION.apk"

    echo "Release v$VERSION created successfully!"
