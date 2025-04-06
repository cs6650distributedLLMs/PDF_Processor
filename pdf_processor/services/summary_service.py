import os
import requests
from dotenv import load_dotenv

load_dotenv()

GROK_API_URL = os.environ.get("GROK_API_URL", "https://api.x.ai/v1/chat/completions")
GROK_API_KEY = os.environ.get("GROK_API_KEY")


def generate_summary(text: str):
    """
    Generate a summary using Grok X API

    Args:
        text (str): The text to summarize

    Returns:
        str: The generated summary
    """
    # Check if the text is too long and truncate if necessary
    max_chars = 15000
    if len(text) > max_chars:
        text = text[:max_chars] + "..."

    if not GROK_API_KEY:
        print("Grok X API key not configured")
        return _generate_mock_summary(text)

    try:
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {GROK_API_KEY}",
        }

        # Prepare the messages for chat completion API
        messages = [
            {
                "role": "system",
                "content": "You are a helpful assistant that creates concise summaries of documents.",
            },
            {
                "role": "user",
                "content": f"Please provide a comprehensive summary of the following text extracted from a PDF. Focus on the main points, key findings, and important details.\n\nTEXT:\n{text}",
            },
        ]

        payload = {
            "messages": messages,
            "model": "grok-2-latest",
            "stream": False,
            "temperature": 0.3,
        }

        response = requests.post(
            GROK_API_URL, headers=headers, json=payload, timeout=30
        )

        # Properly handle response
        response.raise_for_status()

        result = response.json()

        # Extract the summary from the chat completion response
        summary = (
            result.get("choices", [{}])[0].get("message", {}).get("content", "").strip()
        )

        if not summary:
            print("No summary content found in API response")
            return _generate_mock_summary(text)

        return summary

    except requests.exceptions.HTTPError as e:
        print(f"HTTP Error: {e}")
        print(
            f"Response: {e.response.text if hasattr(e, 'response') else 'No response'}"
        )
        return _generate_mock_summary(text)
    except requests.exceptions.ConnectionError as e:
        print(f"Connection Error: {e}")
        return _generate_mock_summary(text)
    except requests.exceptions.Timeout as e:
        print(f"Timeout Error: {e}")
        return _generate_mock_summary(text)
    except requests.exceptions.RequestException as e:
        print(f"Request Exception: {e}")
        return _generate_mock_summary(text)
    except Exception as e:
        print(f"Error generating summary: {e}")
        return _generate_mock_summary(text)


def _generate_mock_summary(text):
    """
    Generate a simple summary without using an external API
    This is a fallback method for when the API is unavailable
    """
    # Implementation remains the same
    paragraphs = text.split("\n\n")
    summary_parts = []

    for para in paragraphs[:5]:
        sentences = para.split(". ")
        if sentences:
            summary_parts.append(sentences[0])

    summary = " ".join(summary_parts)
    summary += "\n\n[Note: This is a basic extraction-based summary generated locally. For better results, configure the Grok X API key.]"

    return summary
