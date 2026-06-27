"""OpenRouter LLM service for general chat/completions."""
from __future__ import annotations

import json
from typing import Optional

import requests

from config import SETTINGS


class OpenRouterLLM:
    """Client for OpenRouter API."""

    BASE_URL = "https://openrouter.ai/api/v1"

    def __init__(
        self,
        api_key: Optional[str] = None,
        model: Optional[str] = None,
    ):
        self.api_key = api_key or SETTINGS.openrouter_api_key
        self.model = model or SETTINGS.openrouter_model
        if not self.api_key:
            raise ValueError("OPENROUTER_API_KEY not configured")

    def chat_completion(
        self,
        messages: list[dict],
        temperature: float = 0.7,
        max_tokens: Optional[int] = None,
        **kwargs,
    ) -> dict:
        """Send a chat completion request to OpenRouter.

        Args:
            messages: List of message dicts with 'role' and 'content'
            temperature: Sampling temperature (0-2)
            max_tokens: Maximum tokens in response
            **kwargs: Additional parameters to pass to API

        Returns:
            Response dict with 'choices' containing completions
        """
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
            "HTTP-Referer": "https://qoyod-archive.local",
            "X-Title": "Qoyod Archive",
        }

        payload = {
            "model": self.model,
            "messages": messages,
            "temperature": temperature,
            **kwargs,
        }

        if max_tokens:
            payload["max_tokens"] = max_tokens

        response = requests.post(
            f"{self.BASE_URL}/chat/completions",
            headers=headers,
            json=payload,
            timeout=30,
        )
        response.raise_for_status()
        return response.json()

    def extract_text(self, response: dict) -> str:
        """Extract text from chat completion response.

        Args:
            response: Response dict from chat_completion

        Returns:
            Text content from first choice
        """
        try:
            return response["choices"][0]["message"]["content"]
        except (KeyError, IndexError) as e:
            raise ValueError(f"Invalid response format: {response}") from e


# Convenience function
def get_llm_client(api_key: Optional[str] = None, model: Optional[str] = None) -> OpenRouterLLM:
    """Get an OpenRouter LLM client."""
    return OpenRouterLLM(api_key=api_key, model=model)


# Example usage
if __name__ == "__main__":
    import os

    # Set API key for testing
    # export OPENROUTER_API_KEY="your_key_here"
    if not os.environ.get("OPENROUTER_API_KEY"):
        print("Error: OPENROUTER_API_KEY not set")
        exit(1)

    client = get_llm_client()
    response = client.chat_completion([{"role": "user", "content": "Hello, how are you?"}])
    print(json.dumps(response, indent=2))
    print("\nExtracted text:", client.extract_text(response))
