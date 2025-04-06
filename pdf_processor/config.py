from dataclasses import dataclass
import os
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()


# Base configuration class
@dataclass(slots=True)
class Config:
    # Flask settings
    SECRET_KEY = os.environ.get("SECRET_KEY", "dev-key-for-local-testing")
    DEBUG = False
    TESTING = False

    # File storage settings
    UPLOAD_FOLDER = os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "uploads/pdfs"
    )
    TEXT_FOLDER = os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "uploads/text"
    )
    SUMMARY_FOLDER = os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "uploads/summaries"
    )
    MAX_CONTENT_LENGTH = 16 * 1024 * 1024  # 16MB max upload size

    # API settings
    GROK_API_URL = os.environ.get(
        "GROK_API_URL", "https://api.x.ai/v1/chat/completions"
    )
    GROK_API_KEY = os.environ.get("GROK_API_KEY", "")


# Development configuration
class DevelopmentConfig(Config):
    DEBUG = True

    # Mock LLM API calls in development if no API key is provided
    ENABLE_MOCK_SUMMARY = not Config.GROK_API_KEY


# Testing configuration
class TestingConfig(Config):
    TESTING = True
    DEBUG = True

    # Use a separate folder for test uploads
    UPLOAD_FOLDER = os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "test_uploads/pdfs"
    )
    TEXT_FOLDER = os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "test_uploads/text"
    )
    SUMMARY_FOLDER = os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "test_uploads/summaries"
    )

    # Always use mock summaries in testing
    ENABLE_MOCK_SUMMARY = True


# Production configuration
class ProductionConfig(Config):
    # In production, these should be set through environment variables
    SECRET_KEY = os.environ.get("SECRET_KEY") or os.urandom(24)


# Configuration dictionary
config = {
    "development": DevelopmentConfig,
    "testing": TestingConfig,
    "production": ProductionConfig,
    "default": DevelopmentConfig,
}


def get_config():
    """Get the current configuration based on environment variables"""
    config_name = os.environ.get("FLASK_ENV", "default")
    return config.get(config_name, config["default"])
