"""API client for local LiteLLM server."""

from typing import List, Dict, Any, Iterator
from anthropic import Anthropic


class RalphAPIClient:
    """Client for communicating with local LiteLLM via Anthropic SDK."""

    def __init__(self, base_url: str = "http://localhost:4000", model: str = "7b"):
        """
        Initialize API client.

        Args:
            base_url: LiteLLM server URL
            model: Model to use ("3b" or "7b")
        """
        self.base_url = base_url

        # Map model shorthand to full model names
        self.model_name = "claude-coder-fast" if model == "3b" else "claude-coder-fake"

        self.conversation_history: List[Dict[str, str]] = []

        # Initialize Anthropic client pointing to local server
        self.client = Anthropic(
            base_url=base_url,
            api_key="dummy-key-local"  # Local server doesn't validate
        )

    def add_message(self, role: str, content: str) -> None:
        """Add message to conversation history."""
        self.conversation_history.append({
            "role": role,
            "content": content
        })

    def clear_history(self) -> None:
        """Clear conversation history."""
        self.conversation_history = []

    def send_message(self, prompt: str, system: str = None) -> str:
        """
        Send message and get complete response.

        Args:
            prompt: User prompt
            system: Optional system prompt

        Returns:
            Assistant's response text
        """
        # Add user message to history
        self.add_message("user", prompt)

        # Build message params
        params = {
            "model": self.model_name,
            "max_tokens": 8192,
            "messages": self.conversation_history
        }

        if system:
            params["system"] = system

        # Send request
        message = self.client.messages.create(**params)

        # Extract response text
        response_text = message.content[0].text

        # Add assistant response to history
        self.add_message("assistant", response_text)

        return response_text

    def stream_message(self, prompt: str, system: str = None) -> Iterator[str]:
        """
        Send message and stream response chunks.

        Args:
            prompt: User prompt
            system: Optional system prompt

        Yields:
            Text chunks as they arrive
        """
        # Add user message to history
        self.add_message("user", prompt)

        # Build message params
        params = {
            "model": self.model_name,
            "max_tokens": 8192,
            "messages": self.conversation_history
        }

        if system:
            params["system"] = system

        # Stream response
        full_response = []

        with self.client.messages.stream(**params) as stream:
            for event in stream:
                if event.type == "content_block_delta":
                    chunk = event.delta.text
                    full_response.append(chunk)
                    yield chunk

        # Add complete response to history
        self.add_message("assistant", "".join(full_response))
