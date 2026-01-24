"""Tests for API client."""

import pytest
from unittest.mock import Mock, patch, MagicMock
from ralph_loop.api_client import RalphAPIClient


def test_api_client_initialization():
    """API client should initialize with correct base URL."""
    client = RalphAPIClient(base_url="http://localhost:4000")

    assert client.base_url == "http://localhost:4000"
    assert client.model_name == "claude-coder-fake"
    assert client.conversation_history == []


def test_api_client_initialization_with_3b_model():
    """API client should use claude-coder-fast for 3B model."""
    client = RalphAPIClient(base_url="http://localhost:4000", model="3b")

    assert client.model_name == "claude-coder-fast"


def test_api_client_adds_message_to_history():
    """Messages should be added to conversation history."""
    client = RalphAPIClient()

    client.add_message("user", "Hello")
    client.add_message("assistant", "Hi there")

    assert len(client.conversation_history) == 2
    assert client.conversation_history[0] == {"role": "user", "content": "Hello"}
    assert client.conversation_history[1] == {"role": "assistant", "content": "Hi there"}


def test_api_client_clears_history():
    """Conversation history should be clearable."""
    client = RalphAPIClient()

    client.add_message("user", "Hello")
    client.add_message("assistant", "Hi")
    assert len(client.conversation_history) == 2

    client.clear_history()
    assert len(client.conversation_history) == 0


@patch('ralph_loop.api_client.Anthropic')
def test_api_client_sends_message(mock_anthropic):
    """API client should send message and return response."""
    # Mock the Anthropic client
    mock_client = Mock()
    mock_anthropic.return_value = mock_client

    mock_message = Mock()
    mock_message.content = [Mock(text="Response text")]
    mock_client.messages.create.return_value = mock_message

    client = RalphAPIClient()
    response = client.send_message("Test prompt")

    assert response == "Response text"
    assert len(client.conversation_history) == 2
    assert client.conversation_history[0]["role"] == "user"
    assert client.conversation_history[1]["role"] == "assistant"


@patch('ralph_loop.api_client.Anthropic')
def test_api_client_streaming(mock_anthropic):
    """API client should handle streaming responses."""
    mock_client = Mock()
    mock_anthropic.return_value = mock_client

    # Mock streaming response
    mock_stream = [
        Mock(type="content_block_delta", delta=Mock(text="Hello ")),
        Mock(type="content_block_delta", delta=Mock(text="world")),
        Mock(type="message_stop")
    ]

    mock_client.messages.stream.return_value.__enter__ = Mock(return_value=mock_stream)
    mock_client.messages.stream.return_value.__exit__ = Mock(return_value=False)

    client = RalphAPIClient()
    chunks = list(client.stream_message("Test prompt"))

    assert chunks == ["Hello ", "world"]
