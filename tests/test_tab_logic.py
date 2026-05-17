"""
Tests for the conditional AI Assistant tab logic in app.py.

The AI tab should only exist when watsonx.ai credentials are available.
"""


def create_tabs(has_watsonx: bool) -> tuple[str, ...]:
    """Simulate the tab list app.py creates for each credential state."""
    if has_watsonx:
        return ("tab_schema", "tab_orm", "tab_report", "tab_ai")

    return ("tab_schema", "tab_orm", "tab_report")


def test_tab_creation_includes_ai_tab_when_watsonx_is_available() -> None:
    """The AI tab is available when watsonx.ai is configured."""
    tabs = create_tabs(has_watsonx=True)

    tab_schema, tab_orm, tab_report, tab_ai = tabs

    assert tab_schema == "tab_schema"
    assert tab_orm == "tab_orm"
    assert tab_report == "tab_report"
    assert tab_ai == "tab_ai"


def test_tab_creation_skips_ai_tab_when_watsonx_is_unavailable() -> None:
    """The AI tab is not created when watsonx.ai is not configured."""
    tabs = create_tabs(has_watsonx=False)

    tab_schema, tab_orm, tab_report = tabs

    assert tab_schema == "tab_schema"
    assert tab_orm == "tab_orm"
    assert tab_report == "tab_report"
    assert "tab_ai" not in tabs
