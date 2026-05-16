import streamlit as st
import sys
from pathlib import Path
import base64

# Add project root to path
sys.path.insert(0, str(Path(__file__).parent))

from parser.sql_parser import SQLParser
from parser.name_normalizer import NameNormalizer
from generator.model_generator import ModelGenerator
from generator.test_generator import TestGenerator
from generator.report_generator import ReportGenerator
from generator.zip_packager import ZipPackager

# ── helpers ──────────────────────────────────────────────────────────────────

def get_base64_image(image_path: str) -> str | None:
    try:
        with open(image_path, "rb") as f:
            return base64.b64encode(f.read()).decode()
    except Exception:
        return None


@st.cache_data(show_spinner=False)
def process_sql_file(sql_content: str) -> dict | None:
    """Parse SQL and generate all output artefacts. Cached by content hash."""
    try:
        parser = SQLParser()
        tables = parser.parse_sql_file(sql_content)

        if not tables:
            st.error("No tables found in SQL file. Please check the file format.")
            return None

        normalizer = NameNormalizer()
        for table in tables:
            table["clean_name"] = normalizer.normalize_table_name(table["original_name"])
            table["table_name"] = normalizer.normalize_table_name_to_tablename(table["clean_name"])
            
            # Reset column context for each table to allow duplicate column names across tables
            normalizer.reset_column_context()
            
            for col in table["columns"]:
                col["clean_name"] = normalizer.normalize_column_name(col["original_name"])

        model_gen     = ModelGenerator()
        models_code   = model_gen.generate_models(tables)
        database_code = model_gen.generate_database_file()

        test_gen   = TestGenerator()
        tests_code = test_gen.generate_tests(tables)

        report_gen           = ReportGenerator()
        readme               = report_gen.generate_readme(tables)
        modernization_report = report_gen.generate_modernization_report(
            tables, normalizer.get_transformation_log()
        )
        requirements = report_gen.generate_requirements()

        files = {
            "models.py":               models_code,
            "database.py":             database_code,
            "test_models.py":          tests_code,
            "README.md":               readme,
            "modernization_report.md": modernization_report,
            "requirements.txt":        requirements,
        }

        zip_data = ZipPackager().create_zip(files)
        tlog     = normalizer.get_transformation_log()

        return {
            "tables":               tables,
            "files":                files,
            "zip_data":             zip_data,
            "table_count":          len(tables),
            "column_count":         sum(len(t["columns"]) for t in tables),
            "transformation_count": len(tlog),
            "transformation_log":   tlog,
        }

    except Exception as e:
        st.error(f"Error processing SQL file: {e}")
        return None


# ── page config ───────────────────────────────────────────────────────────────

st.set_page_config(
    page_title="LegacyLink AI",
    page_icon="assets/icon.png",
    layout="wide",
    initial_sidebar_state="expanded",
)

# ── session state ─────────────────────────────────────────────────────────────

DEFAULTS: dict = {
    "processed":          False,
    "parsed_tables":      None,
    "generated_files":    None,
    "zip_data":           None,
    "stats":              {},
    "transformation_log": [],
    "current_view":       "modernize",  # modernize | history | docs | support
}
for _k, _v in DEFAULTS.items():
    if _k not in st.session_state:
        st.session_state[_k] = _v

# ── CSS ───────────────────────────────────────────────────────────────────────

st.markdown("""
<style>
@import url('https://fonts.googleapis.com/css2?family=JetBrains+Mono:ital,wght@0,400;0,600;0,700;0,900;1,400&display=swap');

/* ── Hide Streamlit chrome ── */
#MainMenu          { visibility: hidden; }
footer             { visibility: hidden; }
.stDeployButton    { display: none !important; }

/* Blend Streamlit header */
[data-testid="stHeader"] {
    background-color: #0D1515 !important;
    border-bottom: 1px solid #3a494a !important;
}

/* ── Global reset ── */
*, *::before, *::after {
    font-family: 'JetBrains Mono', monospace !important;
    box-sizing: border-box;
}
[data-testid="stIconMaterial"] {
    font-family: "Material Symbols Rounded" !important;
}

html, .stApp {
    background-color: #0d1515 !important;
    color: #dce4e4 !important;
}

.main .block-container {
    padding-top: 2rem !important;
    padding-bottom: 5rem !important;
    max-width: 1440px !important;
}

/* ── Sidebar ── */
[data-testid="stSidebar"] {
    background-color: #111318 !important;
    border-right: 1px solid rgba(0,245,255,0.18) !important;
}
[data-testid="stSidebarContent"] {
    padding: 1.25rem 1rem !important;
}
[data-testid="stSidebarCollapseButton"] button {
    color: #00F5FF !important;
    background: transparent !important;
    border: 1px solid #3a494a !important;
}
[data-testid="stSidebar"] [data-testid="stMarkdownContainer"] p {
    color: #dce4e4 !important;
}

/* ── Typography ── */
h1, h2, h3, h4, h5, h6 {
    color: #dce4e4 !important;
    font-family: 'JetBrains Mono', monospace !important;
    font-weight: 700 !important;
    letter-spacing: -0.02em !important;
}
p, span, div, label, li {
    color: #dce4e4;
    font-family: 'JetBrains Mono', monospace !important;
}

/* ── Button base ── */
.stButton > button {
    font-family: 'JetBrains Mono', monospace !important;
    font-weight: 700 !important;
    font-size: 12px !important;
    letter-spacing: 0.1em !important;
    text-transform: uppercase !important;
    border-radius: 0 !important;
    transition: all 0.2s ease !important;
    cursor: pointer !important;
}

/* Primary (solid cyan) */
.stButton > button[data-testid="baseButton-primary"] {
    background-color: #00F5FF !important;
    color: #003739 !important;
    border: none !important;
    padding: 10px 24px !important;
    box-shadow: 0 0 8px rgba(0,245,255,0.3) !important;
}
.stButton > button[data-testid="baseButton-primary"]:hover {
    box-shadow: 0 0 18px rgba(0,245,255,0.6) !important;
    background-color: #63f7ff !important;
}

/* Secondary (ghost) – used for "ghost" action buttons in main area */
.stButton > button[data-testid="baseButton-secondary"] {
    background-color: transparent !important;
    color: #00F5FF !important;
    border: 1px solid #00F5FF !important;
    padding: 10px 24px !important;
    box-shadow: none !important;
}
.stButton > button[data-testid="baseButton-secondary"]:hover {
    background-color: rgba(0,245,255,0.07) !important;
    box-shadow: 0 0 8px rgba(0,245,255,0.25) !important;
}

/* ── Sidebar: NAV buttons override (secondary inside sidebar) ──
   Primary = NEW_MODERNIZATION (keeps cyan fill)
   Secondary = nav items (become transparent, text-only nav links)
*/
[data-testid="stSidebar"] .stButton > button[data-testid="baseButton-secondary"] {
    background-color: transparent !important;
    color: #94A3B8 !important;
    border: none !important;
    box-shadow: none !important;
    text-align: left !important;
    padding: 8px 12px !important;
    text-transform: none !important;
    font-weight: 400 !important;
    letter-spacing: 0.03em !important;
    font-size: 14px !important;
    justify-content: flex-start !important;
    width: 100% !important;
}
[data-testid="stSidebar"] .stButton > button[data-testid="baseButton-secondary"]:hover {
    color: #dce4e4 !important;
    background-color: rgba(255,255,255,0.04) !important;
    box-shadow: none !important;
}

/* Active nav item styling — applied via .nav-active wrapper */
.nav-active .stButton > button[data-testid="baseButton-secondary"] {
    color: #00F5FF !important;
    border-left: 3px solid #00F5FF !important;
    background-color: rgba(0,245,255,0.07) !important;
    box-shadow: -4px 0 12px rgba(0,245,255,0.12) !important;
    padding-left: 9px !important;
}

/* ── File uploader ── */
[data-testid="stFileUploader"] {
    background-color: rgba(25,33,33,0.6) !important;
    border: 1px solid #2e3637 !important;
    border-radius: 0 !important;
    padding: 8px !important;
}
[data-testid="stFileUploader"] section {
    border: 2px dashed rgba(0,245,255,0.45) !important;
    border-radius: 0 !important;
    background-color: transparent !important;
    min-height: 260px !important;
    display: flex !important;
    align-items: center !important;
    justify-content: center !important;
    transition: box-shadow 0.2s, border-color 0.2s !important;
}
[data-testid="stFileUploader"] section:hover,
[data-testid="stFileUploader"] section:focus-within {
    box-shadow: 0 0 20px rgba(0,245,255,0.25) !important;
    border-color: #00F5FF !important;
}
[data-testid="stFileUploaderDropzoneInstructions"] {
    color: #94A3B8 !important;
    font-size: 13px !important;
}

/* ── Code blocks ── */
.stCodeBlock, [data-testid="stCodeBlock"] {
    background-color: #0d1515 !important;
    border: 1px solid #2e3637 !important;
    border-radius: 0 !important;
}
[data-testid="stCodeBlock"] pre {
    background-color: #0d1515 !important;
}
pre, code {
    font-family: 'JetBrains Mono', monospace !important;
    font-size: 13px !important;
    line-height: 22px !important;
    color: #10B981 !important;
}

/* ── Tabs ── */
.stTabs [data-baseweb="tab-list"] {
    background-color: #111318 !important;
    border-bottom: 1px solid #2e3637 !important;
    gap: 0 !important;
}
.stTabs [data-baseweb="tab"] {
    background-color: transparent !important;
    color: #94A3B8 !important;
    font-size: 11px !important;
    font-weight: 700 !important;
    letter-spacing: 0.1em !important;
    text-transform: uppercase !important;
    border-radius: 0 !important;
    padding: 12px 20px !important;
    border-bottom: 2px solid transparent !important;
}
.stTabs [aria-selected="true"] {
    color: #00F5FF !important;
    border-bottom: 2px solid #00F5FF !important;
    background-color: rgba(0,245,255,0.05) !important;
}
.stTabs [data-baseweb="tab-panel"] {
    padding: 24px 0 0 0 !important;
}

/* ── Metrics ── */
[data-testid="stMetric"] {
    background: #192121 !important;
    border: 1px solid #2e3637 !important;
    padding: 16px 20px !important;
}
[data-testid="stMetricValue"] {
    color: #00F5FF !important;
    font-weight: 700 !important;
    font-size: 28px !important;
}
[data-testid="stMetricLabel"] {
    color: #94A3B8 !important;
    font-size: 11px !important;
    font-weight: 700 !important;
    letter-spacing: 0.1em !important;
    text-transform: uppercase !important;
}

/* ── Alerts ── */
.stAlert {
    background-color: #192121 !important;
    border-left: 4px solid #00F5FF !important;
    border-radius: 0 !important;
}

/* ── Expander ── */
.streamlit-expanderHeader {
    background-color: #192121 !important;
    color: #00F5FF !important;
    border: 1px solid #2e3637 !important;
    border-radius: 0 !important;
}

/* ── Download button ── */
[data-testid="stDownloadButton"] > button {
    background-color: transparent !important;
    color: #00F5FF !important;
    border: 1px solid #00F5FF !important;
    border-radius: 0 !important;
    font-family: 'JetBrains Mono', monospace !important;
    font-weight: 700 !important;
    font-size: 12px !important;
    letter-spacing: 0.1em !important;
    text-transform: uppercase !important;
    padding: 10px 24px !important;
    transition: all 0.2s !important;
}
[data-testid="stDownloadButton"] > button:hover {
    background-color: rgba(0,245,255,0.08) !important;
    box-shadow: 0 0 10px rgba(0,245,255,0.3) !important;
}

/* ── Spinner ── */
[data-testid="stSpinner"] { color: #00F5FF !important; }

/* ── Divider ── */
hr { border-color: #2e3637 !important; }

/* ── Selectbox / inputs ── */
[data-testid="stSelectbox"] > div > div {
    background-color: #192121 !important;
    border: 1px solid #2e3637 !important;
    border-radius: 0 !important;
    color: #dce4e4 !important;
}

/* ── Custom utility classes ── */
.cyber-panel {
    background: #192121;
    border: 1px solid #2e3637;
}
.cyber-panel-header {
    background: #232b2c;
    border-bottom: 1px solid #2e3637;
    padding: 9px 16px;
    display: flex;
    align-items: center;
    justify-content: space-between;
}
.terminal-window {
    background: #081010;
    border: 1px solid #2e3637;
    min-height: 340px;
    display: flex;
    flex-direction: column;
}
.terminal-header {
    background: #1E293B;
    border-bottom: 1px solid #334155;
    padding: 10px 16px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    flex-shrink: 0;
}
.terminal-body {
    padding: 24px;
    font-size: 14px;
    line-height: 22px;
    flex: 1;
}
.matrix-green { color: #10B981 !important; }
.neon-cyan    { color: #00F5FF !important; }
.muted-text   { color: #94A3B8 !important; }
.error-red    { color: #EF4444 !important; }

/* Status chips */
.chip {
    display: inline-flex;
    align-items: center;
    gap: 5px;
    padding: 2px 8px;
    font-size: 10px;
    font-weight: 700;
    letter-spacing: 0.1em;
    text-transform: uppercase;
}
.chip-ok   { border: 1px solid #10B981; color: #10B981 !important; }
.chip-crit { border: 1px solid #EF4444; color: #EF4444 !important; }
.chip-warn { border: 1px solid #94A3B8; color: #94A3B8 !important; }
.chip-opt  { border: 1px solid #10B981; color: #10B981 !important; }
.chip-dep  { border: 1px solid #EF4444; color: #EF4444 !important; }

/* ── Schema table ── */
.schema-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 12px;
}
.schema-table th {
    color: #94A3B8;
    text-align: left;
    font-size: 10px;
    letter-spacing: 0.1em;
    font-weight: 700;
    padding: 10px 8px;
    border-bottom: 1px solid #2e3637;
}
.schema-table td {
    padding: 10px 8px;
    border-bottom: 1px solid #192121;
    color: #dce4e4;
    vertical-align: middle;
}
.schema-table tr:hover td {
    background: rgba(0,245,255,0.03);
}
.schema-table .row-active td {
    background: rgba(0,245,255,0.04);
    border-left: 3px solid #00F5FF;
}

/* ── Transformation log table ── */
.tlog-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 12px;
}
.tlog-table th {
    color: #94A3B8;
    font-size: 10px;
    letter-spacing: 0.1em;
    font-weight: 700;
    padding: 10px 8px;
    border-bottom: 1px solid #2e3637;
    text-align: left;
}
.tlog-table td { padding: 14px 8px; border-bottom: 1px solid #192121; vertical-align: top; }
.tlog-table tr:hover td { background: rgba(255,255,255,0.02); }

/* ── Bar chart for patterns ── */
.bar-chart {
    display: flex;
    align-items: flex-end;
    gap: 12px;
    height: 140px;
    padding: 0 8px;
    margin-bottom: 12px;
}
.bar-col {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 4px;
    flex: 1;
}
.bar-col span {
    color: #94A3B8 !important;
    font-size: 10px;
    letter-spacing: 0.05em;
    white-space: nowrap;
}

/* ── Sidebar divider ── */
.sidebar-divider {
    margin: 14px 0;
    border: none;
    border-top: 1px solid #2e3637;
}

/* ── Footer ── */
.legacylink-footer {
    position: fixed;
    bottom: 0;
    left: 0;
    right: 0;
    background: rgba(8,16,16,0.96);
    backdrop-filter: blur(12px);
    -webkit-backdrop-filter: blur(12px);
    border-top: 1px solid #2e3637;
    padding: 8px 40px;
    display: flex;
    justify-content: space-between;
    align-items: center;
    z-index: 1000;
}

/* ── Progress bar ── */
[data-testid="stProgressBar"] > div > div {
    background-color: #00F5FF !important;
    border-radius: 0 !important;
}
[data-testid="stProgressBar"] > div {
    background-color: #1E293B !important;
    border-radius: 0 !important;
    height: 4px !important;
}

/* ── Spinner text ── */
[data-testid="stSpinner"] p { color: #00F5FF !important; }
</style>
""", unsafe_allow_html=True)

# ── Sidebar ───────────────────────────────────────────────────────────────────

with st.sidebar:
    # Logo / brand
    icon_b64 = get_base64_image("assets/icon.png")
    if icon_b64:
        logo_html = (
            f"<img src='data:image/png;base64,{icon_b64}' "
            "style='width:32px;height:32px;object-fit:contain;"
            "border:1px solid #00F5FF;background:#1E293B;padding:3px;'/>"
        )
    else:
        logo_html = (
            "<div style='width:32px;height:32px;background:#1E293B;"
            "border:1px solid #00F5FF;display:flex;align-items:center;"
            "justify-content:center;font-size:16px;flex-shrink:0;'>⚡</div>"
        )

    st.markdown(f"""
    <div style='display:flex;align-items:center;gap:12px;margin-bottom:24px;'>
        {logo_html}
        <div>
            <div style='color:#00F5FF;font-size:13px;font-weight:700;
                        letter-spacing:0.08em;line-height:1.2;'>LEGACY_LINK</div>
            <div style='color:#849495;font-size:10px;letter-spacing:0.1em;
                        margin-top:2px;'>V2.0_STABLE</div>
        </div>
    </div>
    """, unsafe_allow_html=True)

    # NEW_MODERNIZATION — primary (cyan fill)
    if st.button("+ NEW_MODERNIZATION", type="primary",
                 use_container_width=True, key="btn_new_mod"):
        for k in list(DEFAULTS.keys()):
            st.session_state[k] = DEFAULTS[k]
        st.session_state.current_view = "modernize"
        st.rerun()

    st.markdown("<hr class='sidebar-divider'>", unsafe_allow_html=True)

    # Navigation items — secondary buttons (styled as text nav via CSS)
    NAV_ITEMS = [
        ("modernize", "⚡", "Modernize"),
        ("history",   "⟳", "History"),
        ("docs",      "☰", "Documentation"),
        ("support",   "◎", "Support"),
    ]
    for nav_key, icon, label in NAV_ITEMS:
        is_active = st.session_state.current_view == nav_key
        # Wrap in a div that the CSS .nav-active selector targets
        if is_active:
            st.markdown("<div class='nav-active'>", unsafe_allow_html=True)
        if st.button(f"{icon}  {label}", type="secondary",
                     key=f"nav_{nav_key}", use_container_width=True):
            st.session_state.current_view = nav_key
            st.rerun()
        if is_active:
            st.markdown("</div>", unsafe_allow_html=True)

# ── Main content ───────────────────────────────────────────────────────────────

view = st.session_state.current_view

# ══════════════════════════════════════════════════════════════════════════════
# MODERNIZE VIEW
# ══════════════════════════════════════════════════════════════════════════════

if view == "modernize":

    # ── Upload / Landing (not yet processed) ──────────────────────────────────
    if not st.session_state.processed:

        # Hero section
        st.markdown("""
        <div style='text-align:center;margin-top:16px;margin-bottom:40px;'>
            <h1 style='font-size:38px !important;line-height:48px !important;
                       color:#dce4e4 !important;margin-bottom:16px;font-weight:700;'>
                IBM Bob-assisted<br>
                <span style='color:#00F5FF;'>legacy SQL schema modernization</span>
            </h1>
            <p style='color:#94A3B8;font-size:15px;line-height:24px;
                      max-width:680px;margin:0 auto 32px;'>
                Instantly translate archaic database structures into pristine,
                modern architectures. Upload your legacy SQL files and let AI handle
                the heavy lifting of schema normalisation, type mapping, and
                constraint generation.
            </p>
            <div style='display:flex;gap:16px;justify-content:center;'>
                <div style='background:#00F5FF;color:#003739;font-weight:700;
                            font-size:12px;letter-spacing:0.1em;padding:12px 32px;
                            cursor:pointer;box-shadow:0 0 14px rgba(0,245,255,0.35);'>
                    GET STARTED
                </div>
                <div style='border:1px solid #00F5FF;color:#00F5FF;font-weight:700;
                            font-size:12px;letter-spacing:0.1em;padding:12px 32px;
                            cursor:pointer;'>
                    VIEW DOCUMENTATION
                </div>
            </div>
        </div>
        """, unsafe_allow_html=True)

        col_upload, col_terminal = st.columns(2, gap="large")

        with col_upload:
            uploaded_file = st.file_uploader(
                "Drag & Drop SQL File",
                type=["sql", "ddl", "txt"],
                label_visibility="collapsed",
            )
            if uploaded_file:
                st.markdown(f"""
                <div style='background:#0d2a1e;border:1px solid #10B981;
                            padding:8px 14px;margin-top:8px;font-size:12px;
                            display:flex;align-items:center;gap:8px;'>
                    <span style='color:#10B981;font-weight:700;'>✓</span>
                    <span style='color:#dce4e4;'>
                        {uploaded_file.name}
                        <span style='color:#849495;'> ({uploaded_file.size:,} bytes)</span>
                    </span>
                </div>
                """, unsafe_allow_html=True)
                st.markdown("<div style='margin-top:12px;'></div>", unsafe_allow_html=True)
                if st.button("⬆ PROCESS SQL FILE", type="primary",
                             use_container_width=True, key="btn_process"):
                    with st.spinner("Parsing schema and generating artefacts…"):
                        sql_content = uploaded_file.read().decode("utf-8")
                        result = process_sql_file(sql_content)
                    if result:
                        st.session_state.processed           = True
                        st.session_state.parsed_tables       = result["tables"]
                        st.session_state.generated_files     = result["files"]
                        st.session_state.zip_data            = result["zip_data"]
                        st.session_state.transformation_log  = result["transformation_log"]
                        st.session_state.stats = {
                            "table_count":          result["table_count"],
                            "column_count":         result["column_count"],
                            "transformation_count": result["transformation_count"],
                        }
                        st.rerun()

        with col_terminal:
            st.markdown("""
            <div class='terminal-window'>
                <div class='terminal-header'>
                    <span style='color:#849495;font-size:12px;letter-spacing:0.1em;'>
                        preview_terminal.sh
                    </span>
                    <div style='display:flex;gap:6px;'>
                        <div style='width:10px;height:10px;border-radius:50%;
                                    background:#2e3637;border:1px solid #3a494a;'></div>
                        <div style='width:10px;height:10px;border-radius:50%;
                                    background:#2e3637;border:1px solid #3a494a;'></div>
                        <div style='width:10px;height:10px;border-radius:50%;
                                    background:#2e3637;border:1px solid #3a494a;'></div>
                    </div>
                </div>
                <div class='terminal-body'>
                    <div style='color:#849495;margin-bottom:20px;font-style:italic;'>
                        // Waiting for input…
                    </div>
                    <div style='color:#10B981;margin-bottom:6px;'>&gt; SYSTEM_READY</div>
                    <div style='color:#10B981;margin-bottom:6px;'>&gt; IBM_BOB_ASSISTED_WORKFLOW_READY</div>
                    <div style='color:#10B981;margin-bottom:32px;'>&gt; AWAITING_LEGACY_SCHEMA</div>
                    <div style='margin-top:auto;padding-top:24px;
                                border-top:1px solid #1E293B;opacity:0.7;'>
                        <div style='display:flex;align-items:center;gap:10px;'>
                            <div style='width:8px;height:8px;border-radius:50%;
                                        background:#849495;'></div>
                            <span style='color:#849495;font-size:12px;letter-spacing:0.05em;'>
                                Processing Engine Idle
                            </span>
                        </div>
                    </div>
                </div>
            </div>
            """, unsafe_allow_html=True)

    # ── Results (processed) ────────────────────────────────────────────────────
    else:
        files  = st.session_state.generated_files
        tables = st.session_state.parsed_tables
        stats  = st.session_state.stats
        tlog   = st.session_state.transformation_log
        
        # Calculate actual statistics from parsed data
        total_columns = sum(len(t["columns"]) for t in tables)
        total_pks = sum(1 for t in tables for c in t["columns"] if c.get("primary_key"))
        total_fks = sum(1 for t in tables for c in t["columns"] if c["clean_name"].endswith("_id") and not c.get("primary_key"))

        if not all([files, tables]):
            st.error("Session data missing — please upload and process a SQL file.")
            if st.button("↺ Reset", type="primary"):
                st.session_state.processed = False
                st.rerun()
        else:
            tab_schema, tab_orm, tab_report = st.tabs([
                "☰  SCHEMA OVERVIEW",
                "{ }  GENERATED ORM",
                "⊕  MODERNIZATION REPORT",
            ])

            # ══════════════════════════════════════════════════════════════════
            # TAB 1 — Parsed Schema Extractor  (matches dashboard.png)
            # ══════════════════════════════════════════════════════════════════
            with tab_schema:
                # Header row
                h1, h2, h3 = st.columns([3, 1, 1])
                with h1:
                    st.markdown(f"""
                    <div style='margin-bottom:20px;'>
                        <h2 style='margin:0 0 4px;font-size:28px !important;'>
                            Parsed Schema Extractor
                        </h2>
                        <p style='color:#849495;font-size:13px;margin:0;'>
                            SCAN_ID:&nbsp;
                            <span style='color:#00F5FF;'>SYS_DUMP_AUTO</span>
                            &nbsp;|&nbsp; TABLES_FOUND:&nbsp;
                            <span style='color:#00F5FF;'>{stats['table_count']}</span>
                        </p>
                    </div>
                    """, unsafe_allow_html=True)
                with h2:
                    st.button("EXPORT_MAP", type="secondary", key="btn_export_map")
                with h3:
                    st.button("BEGIN_TRANSFORMATION", type="primary", key="btn_begin")

                left_panel, right_panel = st.columns([1.3, 1], gap="medium")

                with left_panel:
                    # Build table rows HTML
                    rows_html = ""
                    for i, t in enumerate(tables[:12]):
                        col_count = len(t["columns"])
                        has_pk    = any(c.get("primary_key") for c in t["columns"])
                        health    = "OK"   if has_pk else "CRIT"
                        h_color   = "#10B981" if has_pk else "#EF4444"
                        row_style = (
                            "background:rgba(0,245,255,0.04);border-left:3px solid #00F5FF;"
                            if i == 0 else ""
                        )
                        name_color = "#00F5FF" if i == 0 else "#dce4e4"
                        rows_html += f"""
                        <tr style='{row_style}'>
                            <td style='padding:10px 10px 10px {8 if i > 0 else 5}px;
                                       color:{name_color};font-size:12px;
                                       border-bottom:1px solid #192121;'>
                                {t['original_name']}
                            </td>
                            <td style='padding:10px;color:#849495;text-align:right;
                                       border-bottom:1px solid #192121;'>{col_count}</td>
                            <td style='padding:10px;text-align:right;
                                       border-bottom:1px solid #192121;'>
                                <span style='color:{h_color};font-size:10px;
                                             letter-spacing:0.1em;font-weight:700;'>
                                    {health}
                                </span>
                            </td>
                        </tr>
                        """

                    st.markdown(f"""
                    <div class='cyber-panel'>
                        <div class='cyber-panel-header'>
                            <span style='color:#849495;font-size:11px;
                                         letter-spacing:0.1em;font-weight:700;'>
                                ☰ &nbsp;EXTRACTED_TABLES
                            </span>
                            <div style='display:flex;gap:8px;'>
                                <span style='color:#849495;font-size:14px;cursor:pointer;'>⇅</span>
                            </div>
                        </div>
                        <div style='padding:0 12px 8px;'>
                            <table class='schema-table'>
                                <thead>
                                    <tr>
                                        <th>TABLE_NAME</th>
                                        <th style='text-align:right;'>COLS</th>
                                        <th style='text-align:right;'>HEALTH_SCORE</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    {rows_html}
                                </tbody>
                            </table>
                        </div>
                    </div>
                    """, unsafe_allow_html=True)

                with right_panel:
                    if tables:
                        t = tables[0]
                        # Column rows for inspector
                        col_rows = ""
                        for col in t["columns"][:8]:
                            pk_badge = (
                                "<span style='color:#00F5FF;font-size:10px;"
                                "font-weight:700;margin-left:6px;'>PRI</span>"
                                if col.get("primary_key") else ""
                            )
                            # Highlight suspect types red
                            is_suspect = (
                                "VARCHAR" in col["type"].upper()
                                and any(kw in col["original_name"].lower()
                                        for kw in ["amount","price","value","bal"])
                            )
                            type_color = "#EF4444" if is_suspect else "#849495"
                            col_rows += f"""
                            <div style='display:flex;justify-content:space-between;
                                        align-items:center;padding:7px 14px;
                                        border-bottom:1px solid #192121;'>
                                <span style='color:#dce4e4;font-size:12px;'>
                                    {col['original_name']}{pk_badge}
                                </span>
                                <span style='color:{type_color};font-size:12px;'>
                                    {col['type']}
                                </span>
                            </div>
                            """

                        # Anomaly detection
                        anomalies = [
                            col for col in t["columns"]
                            if "VARCHAR" in col["type"].upper()
                            and any(kw in col["original_name"].lower()
                                    for kw in ["amount","price","value","bal","num"])
                        ]
                        missing_fk = [
                            col for col in t["columns"]
                            if col["original_name"].lower().endswith(("_id","_fk","_key"))
                            and not col.get("primary_key")
                        ]

                        anomaly_html = ""
                        if anomalies or missing_fk:
                            items = ""
                            for col in anomalies[:2]:
                                items += f"<li style='margin-bottom:4px;'>" \
                                         f"Financial value <code style='color:#10B981;" \
                                         f"background:transparent;font-size:11px;'>" \
                                         f"`{col['original_name']}`</code> " \
                                         f"stored as {col['type']}.</li>"
                            for col in missing_fk[:1]:
                                items += f"<li style='margin-bottom:4px;'>" \
                                         f"Possible missing FK constraint on " \
                                         f"<code style='color:#10B981;background:transparent;" \
                                         f"font-size:11px;'>`{col['original_name']}`</code>.</li>"
                            anomaly_html = f"""
                            <div style='margin:14px;background:rgba(239,68,68,0.07);
                                        border:1px solid rgba(239,68,68,0.3);padding:12px;'>
                                <div style='color:#EF4444;font-size:11px;font-weight:700;
                                            letter-spacing:0.08em;margin-bottom:8px;'>
                                    ⚠ ANOMALIES_DETECTED
                                </div>
                                <ul style='margin:0;padding-left:16px;color:#dce4e4;
                                           font-size:12px;line-height:20px;'>
                                    {items}
                                </ul>
                            </div>
                            """

                        st.markdown(f"""
                        <div class='cyber-panel'>
                            <div class='cyber-panel-header'>
                                <span style='color:#849495;font-size:11px;
                                             letter-spacing:0.1em;font-weight:700;'>
                                    ⚙ &nbsp;TABLE_INSPECTOR
                                </span>
                            </div>
                            <div style='padding:16px;'>
                                <div style='color:#00F5FF;font-size:17px;font-weight:700;
                                            margin-bottom:3px;letter-spacing:-0.01em;'>
                                    {t['original_name']}
                                </div>
                                <div style='color:#849495;font-size:11px;
                                            letter-spacing:0.05em;margin-bottom:16px;'>
                                    COLUMNS:&nbsp;{len(t['columns'])}
                                    &nbsp;|&nbsp; STATUS:&nbsp;DETECTED
                                </div>
                                <div style='font-size:10px;letter-spacing:0.1em;
                                            color:#849495;font-weight:700;margin-bottom:8px;'>
                                    DETECTED_SCHEMA
                                </div>
                            </div>
                            <div style='border-top:1px solid #2e3637;'>
                                {col_rows}
                            </div>
                            {anomaly_html}
                        </div>
                        """, unsafe_allow_html=True)

            # ══════════════════════════════════════════════════════════════════
            # TAB 2 — Generated ORM  (matches orm.png)
            # ══════════════════════════════════════════════════════════════════
            with tab_orm:
                h1, h2, h3 = st.columns([3, 1, 1])
                with h1:
                    st.markdown("""
                    <div style='margin-bottom:20px;'>
                        <h2 style='margin:0 0 4px;font-size:28px !important;'>
                            Generated ORM
                        </h2>
                        <p style='color:#849495;font-size:13px;margin:0;'>
                            SQLAlchemy 2.0 Models generated from legacy schema.
                            Ready for integration.
                        </p>
                    </div>
                    """, unsafe_allow_html=True)
                with h2:
                    st.button("✎  EDIT MODELS", type="secondary", key="btn_edit_models")
                with h3:
                    if st.session_state.zip_data:
                        st.download_button(
                            "⬇  DOWNLOAD ZIP",
                            data=st.session_state.zip_data,
                            file_name="legacylink_project.zip",
                            mime="application/zip",
                            key="dl_zip_orm",
                        )

                left_code, right_code = st.columns(2, gap="medium")

                # Reconstruct a readable legacy SQL snippet
                legacy_snippet = ""
                for t in tables[:3]:
                    legacy_snippet += f"CREATE TABLE {t['original_name']} (\n"
                    for col in t["columns"]:
                        pk  = " PRIMARY KEY" if col.get("primary_key") else ""
                        nn  = " NOT NULL"    if not col.get("nullable") else ""
                        legacy_snippet += f"    {col['original_name']} {col['type']}{nn}{pk},\n"
                    legacy_snippet = legacy_snippet.rstrip(",\n") + "\n);\n\n"

                with left_code:
                    st.markdown("""
                    <div style='background:#1E293B;border:1px solid #2e3637;
                                padding:9px 16px;display:flex;justify-content:space-between;
                                align-items:center;'>
                        <span style='color:#849495;font-size:11px;letter-spacing:0.08em;
                                     font-weight:700;'>LEGACY_SCHEMA.SQL</span>
                        <span class='chip chip-dep'>⚠ DEPRECATED</span>
                    </div>
                    """, unsafe_allow_html=True)
                    st.code(legacy_snippet.strip(), language="sql")

                with right_code:
                    st.markdown("""
                    <div style='background:#1E293B;border:1px solid #2e3637;
                                padding:9px 16px;display:flex;justify-content:space-between;
                                align-items:center;'>
                        <span style='color:#849495;font-size:11px;letter-spacing:0.08em;
                                     font-weight:700;'>MODELS.PY (SQLALCHEMY 2.0)</span>
                        <span class='chip chip-opt'>✓ OPTIMIZED</span>
                    </div>
                    """, unsafe_allow_html=True)
                    st.code(files["models.py"], language="python")

                # database.py expander
                with st.expander("▸  View database.py"):
                    st.code(files["database.py"], language="python")

                with st.expander("▸  View test_models.py"):
                    st.code(files["test_models.py"], language="python")

            # ══════════════════════════════════════════════════════════════════
            # TAB 3 — Modernization Report  (matches report.png)
            # ══════════════════════════════════════════════════════════════════
            with tab_report:
                h1, h2, h3 = st.columns([3, 1, 1])
                with h1:
                    st.markdown("""
                    <div style='margin-bottom:20px;'>
                        <h2 style='margin:0 0 4px;font-size:28px !important;'>
                            ⊕ Modernization Report
                        </h2>
                        <p style='color:#849495;font-size:13px;margin:0;'>
                            Transformation analysis for database schema
                            <span style='color:#00F5FF;'>db_legacy_prod_v4</span>.
                        </p>
                    </div>
                    """, unsafe_allow_html=True)
                with h2:
                    st.download_button(
                        "⬇  EXPORT JSON",
                        data=files.get("modernization_report.md", ""),
                        file_name="modernization_report.md",
                        mime="text/markdown",
                        key="dl_report",
                    )
                with h3:
                    st.button("APPLY CHANGES", type="primary", key="btn_apply")

                # Summary + chart row
                sum_col, chart_col = st.columns([1, 1.5], gap="medium")
                total_entities = stats["table_count"] + stats["column_count"]

                with sum_col:
                    st.markdown(f"""
                    <div class='cyber-panel' style='padding:24px;'>
                        <div style='font-size:10px;letter-spacing:0.1em;color:#849495;
                                    font-weight:700;margin-bottom:16px;'>
                            ⊕ &nbsp;TRANSFORMATION SUMMARY
                        </div>
                        <div style='color:#00F5FF;font-size:52px;font-weight:700;
                                    line-height:1;margin-bottom:6px;'>
                            {total_entities:,}
                        </div>
                        <div style='color:#849495;font-size:13px;margin-bottom:20px;'>
                            Total Entities Processed
                        </div>
                        <div style='display:flex;justify-content:space-between;
                                    padding:12px 0;border-top:1px solid #2e3637;'>
                            <span style='color:#849495;font-size:13px;'>Tables Renamed</span>
                            <span style='color:#dce4e4;font-weight:700;font-size:15px;'>
                                {stats['table_count']}
                            </span>
                        </div>
                        <div style='display:flex;justify-content:space-between;
                                    padding:12px 0;border-top:1px solid #2e3637;'>
                            <span style='color:#849495;font-size:13px;'>Columns Standardized</span>
                            <span style='color:#dce4e4;font-weight:700;font-size:15px;'>
                                {stats['column_count']:,}
                            </span>
                        </div>
                        <div style='padding:14px 0 0;border-top:1px solid #2e3637;'>
                            <div style='display:flex;justify-content:space-between;
                                        margin-bottom:8px;'>
                                <span style='font-size:10px;letter-spacing:0.1em;
                                             color:#849495;font-weight:700;'>
                                    CONFIDENCE SCORE
                                </span>
                                <span style='color:#00F5FF;font-weight:700;font-size:14px;'>94%</span>
                            </div>
                            <div style='background:#1E293B;height:4px;'>
                                <div style='background:linear-gradient(90deg,#00dce5,#00F5FF);
                                            height:100%;width:94%;'></div>
                            </div>
                        </div>
                    </div>
                    """, unsafe_allow_html=True)

                with chart_col:
                    # Detect pattern counts from tables
                    hung  = sum(1 for t in tables if any(
                        t["original_name"].lower().startswith(p)
                        for p in ["tbl_","vw_","str","dtm","int","chr"]))
                    acr   = sum(1 for t in tables if any(
                        abbr in t["original_name"].upper()
                        for abbr in ["CUST","MSTR","DTL","USR","EMP","ORD"]))
                    red   = max(0, stats["table_count"] - hung - acr)
                    other = max(0, stats["table_count"] - hung - acr - red)
                    total_pat = max(hung + acr + red + other, 1)

                    def bar_h(n, max_h=130):
                        return max(10, int(n / total_pat * max_h))

                    st.markdown(f"""
                    <div class='cyber-panel' style='padding:24px;'>
                        <div style='font-size:10px;letter-spacing:0.1em;color:#849495;
                                    font-weight:700;margin-bottom:20px;'>
                            ⊕ &nbsp;DETECTED LEGACY PATTERNS
                        </div>
                        <div class='bar-chart'>
                            <div class='bar-col'>
                                <div style='background:#7B2D2D;width:100%;
                                            height:{bar_h(hung)}px;'></div>
                                <span>Hungarian</span>
                            </div>
                            <div class='bar-col'>
                                <div style='background:#334155;width:100%;
                                            height:{bar_h(acr)}px;'></div>
                                <span>Acronyms</span>
                            </div>
                            <div class='bar-col'>
                                <div style='background:#2d3748;width:100%;
                                            height:{bar_h(max(0,acr//2))}px;'></div>
                                <span>Type Pfx</span>
                            </div>
                            <div class='bar-col'>
                                <div style='background:#1E4D3B;width:100%;
                                            height:{bar_h(red)}px;'></div>
                                <span>Redundant</span>
                            </div>
                            <div class='bar-col'>
                                <div style='background:#1E293B;width:100%;
                                            height:{bar_h(max(1,other))}px;'></div>
                                <span>Other</span>
                            </div>
                        </div>
                        <div style='display:flex;gap:20px;flex-wrap:wrap;margin-top:4px;'>
                            <div style='display:flex;align-items:center;gap:6px;'>
                                <div style='width:10px;height:10px;background:#7B2D2D;
                                            flex-shrink:0;'></div>
                                <span style='color:#849495;font-size:10px;'>
                                    Hungarian Notation<br>
                                    <span style='color:#94A3B8;font-size:9px;'>tbl_, vw_, str_</span>
                                </span>
                            </div>
                            <div style='display:flex;align-items:center;gap:6px;'>
                                <div style='width:10px;height:10px;background:#334155;
                                            flex-shrink:0;'></div>
                                <span style='color:#849495;font-size:10px;'>
                                    Cryptic Acronyms<br>
                                    <span style='color:#94A3B8;font-size:9px;'>CUST, MSTR, DTL</span>
                                </span>
                            </div>
                            <div style='display:flex;align-items:center;gap:6px;'>
                                <div style='width:10px;height:10px;background:#1E4D3B;
                                            flex-shrink:0;'></div>
                                <span style='color:#849495;font-size:10px;'>
                                    Redundant Context<br>
                                    <span style='color:#94A3B8;font-size:9px;'>User_UserId</span>
                                </span>
                            </div>
                        </div>
                    </div>
                    """, unsafe_allow_html=True)

                # Transformation Log (using actual transformation log data)
                st.markdown("<div style='margin-top:24px;'></div>", unsafe_allow_html=True)

                log_rows_html = ""
                
                # Show table transformations
                for t in tables[:6]:
                    log_rows_html += f"""
                    <tr>
                        <td>
                            <div style='width:28px;height:28px;border:1px solid #10B981;
                                        display:flex;align-items:center;justify-content:center;'>
                                <span style='color:#10B981;font-size:14px;'>✓</span>
                            </div>
                        </td>
                        <td>
                            <div style='color:#EF4444;font-size:12px;font-weight:600;
                                        margin-bottom:2px;'>{t['original_name']}</div>
                            <div style='color:#849495;font-size:11px;'>
                                Table · Legacy Naming Pattern
                            </div>
                        </td>
                        <td style='color:#849495;font-size:16px;text-align:center;'>→</td>
                        <td>
                            <div style='color:#10B981;font-size:12px;font-weight:600;
                                        margin-bottom:2px;'>{t['clean_name']}</div>
                            <div style='color:#849495;font-size:11px;'>
                                Class: {t['clean_name']} | Table: {t['table_name']}
                            </div>
                        </td>
                    </tr>
                    """
                
                # Show column transformations from first table
                if tables and len(tables[0]["columns"]) > 0:
                    first_table_cols = tables[0]["columns"][:5]  # Show first 5 columns
                    for col in first_table_cols:
                        if col['original_name'] != col['clean_name']:
                            log_rows_html += f"""
                            <tr>
                                <td>
                                    <div style='width:28px;height:28px;border:1px solid #3B82F6;
                                                display:flex;align-items:center;justify-content:center;'>
                                        <span style='color:#3B82F6;font-size:14px;'>✓</span>
                                    </div>
                                </td>
                                <td>
                                    <div style='color:#F59E0B;font-size:12px;font-weight:600;
                                                margin-bottom:2px;'>{col['original_name']}</div>
                                    <div style='color:#849495;font-size:11px;'>
                                        Column · {tables[0]['original_name']}
                                    </div>
                                </td>
                                <td style='color:#849495;font-size:16px;text-align:center;'>→</td>
                                <td>
                                    <div style='color:#3B82F6;font-size:12px;font-weight:600;
                                                margin-bottom:2px;'>{col['clean_name']}</div>
                                    <div style='color:#849495;font-size:11px;'>
                                        Type: {col['type']} | Normalized
                                    </div>
                                </td>
                            </tr>
                            """

                st.markdown(f"""
                <div class='cyber-panel'>
                    <div class='cyber-panel-header'>
                        <span style='font-size:10px;letter-spacing:0.1em;
                                     color:#849495;font-weight:700;'>
                            TRANSFORMATION LOG
                        </span>
                        <div style='border:1px solid #3a494a;padding:4px 12px;
                                    font-size:10px;letter-spacing:0.08em;color:#849495;
                                    cursor:pointer;'>
                            ALL ENTITIES &nbsp;▾
                        </div>
                    </div>
                    <div style='padding:0 12px 8px;'>
                        <table class='tlog-table'>
                            <thead>
                                <tr>
                                    <th style='width:50px;'>STATUS</th>
                                    <th>LEGACY SIGNATURE</th>
                                    <th style='width:48px;'></th>
                                    <th>CLEAN ARCHITECTURE NAME</th>
                                </tr>
                            </thead>
                            <tbody>
                                {log_rows_html}
                            </tbody>
                        </table>
                    </div>
                </div>
                """, unsafe_allow_html=True)

                # Download full zip
                st.markdown("<div style='margin-top:20px;'></div>", unsafe_allow_html=True)
                if st.session_state.zip_data:
                    st.download_button(
                        "⬇  DOWNLOAD COMPLETE PROJECT (ZIP)",
                        data=st.session_state.zip_data,
                        file_name="legacylink_generated_project.zip",
                        mime="application/zip",
                        use_container_width=True,
                        key="dl_zip_report",
                    )

# ══════════════════════════════════════════════════════════════════════════════
# HISTORY VIEW
# ══════════════════════════════════════════════════════════════════════════════

elif view == "history":
    st.markdown("""
    <h2 style='font-size:28px !important;margin-bottom:8px;'>⟳ &nbsp;History</h2>
    <p style='color:#849495;margin-bottom:32px;'>
        Previous modernization sessions are listed below.
    </p>
    <div class='cyber-panel' style='padding:40px;text-align:center;'>
        <div style='color:#849495;font-size:32px;margin-bottom:16px;'>◎</div>
        <div style='color:#94A3B8;font-size:14px;'>NO_SESSIONS_FOUND</div>
        <div style='color:#849495;font-size:12px;margin-top:6px;'>
            Upload a SQL file on the Modernize tab to get started.
        </div>
    </div>
    """, unsafe_allow_html=True)

# ══════════════════════════════════════════════════════════════════════════════
# DOCS VIEW
# ══════════════════════════════════════════════════════════════════════════════

elif view == "docs":
    st.markdown("""
    <h2 style='font-size:28px !important;margin-bottom:8px;'>☰ &nbsp;Documentation</h2>
    <p style='color:#849495;margin-bottom:32px;'>
        API reference and integration guides.
    </p>
    """, unsafe_allow_html=True)

    for title, body in [
        ("GETTING STARTED",
         "Upload any <code>.sql</code>, <code>.ddl</code>, or <code>.txt</code> legacy schema dump. "
         "LegacyLink AI parses it, detects legacy patterns, and generates clean SQLAlchemy 2.0 ORM models."),
        ("SUPPORTED PATTERNS",
         "Hungarian Notation, Cryptic Acronyms (CUST, MSTR, DTL), Type Prefixes (str, dtm, int), "
         "Redundant Context names (User_UserId), and inconsistent casing."),
        ("OUTPUT FILES",
         "<code>models.py</code> — SQLAlchemy 2.0 declarative models<br>"
         "<code>database.py</code> — Engine and session setup<br>"
         "<code>test_models.py</code> — pytest test suite<br>"
         "<code>README.md</code> — Integration guide<br>"
         "<code>modernization_report.md</code> — Transformation analysis"),
    ]:
        st.markdown(f"""
        <div class='cyber-panel' style='padding:20px 24px;margin-bottom:12px;'>
            <div style='color:#00F5FF;font-size:11px;font-weight:700;
                        letter-spacing:0.1em;margin-bottom:10px;'>{title}</div>
            <div style='color:#b9caca;font-size:13px;line-height:22px;'>{body}</div>
        </div>
        """, unsafe_allow_html=True)

# ══════════════════════════════════════════════════════════════════════════════
# SUPPORT VIEW
# ══════════════════════════════════════════════════════════════════════════════

elif view == "support":
    st.markdown("""
    <h2 style='font-size:28px !important;margin-bottom:8px;'>◎ &nbsp;Support</h2>
    <p style='color:#849495;margin-bottom:32px;'>
        Contact the IBM Bob support team for assistance.
    </p>
    """, unsafe_allow_html=True)

    for icon, title, detail in [
        ("◈", "SYSTEM STATUS",  "All systems operational. IBM_BOB_ASSISTED_DEVELOPMENT: ENABLED"),
        ("◉", "VERSION",        "LegacyLink AI v2.0_STABLE — Parser v3.1 · Generator v2.4"),
        ("◎", "CONTACT",        "Submit a support ticket via the IBM Watsonx portal"),
    ]:
        st.markdown(f"""
        <div class='cyber-panel' style='padding:20px 24px;margin-bottom:12px;
                                         display:flex;align-items:center;gap:20px;'>
            <div style='color:#00F5FF;font-size:24px;flex-shrink:0;'>{icon}</div>
            <div>
                <div style='color:#00F5FF;font-size:11px;font-weight:700;
                            letter-spacing:0.1em;margin-bottom:4px;'>{title}</div>
                <div style='color:#b9caca;font-size:13px;'>{detail}</div>
            </div>
        </div>
        """, unsafe_allow_html=True)

# ── Footer ────────────────────────────────────────────────────────────────────

st.markdown("""
<div class='legacylink-footer'>
    <span style='color:#10B981;font-size:11px;letter-spacing:0.1em;font-weight:700;'>
        MODERNIZATION_PROGRESS: 87% &nbsp;|&nbsp; SYSTEM_READY
    </span>
    <span style='color:#849495;font-size:11px;letter-spacing:0.08em;'>
        PRIVACY POLICY &nbsp;&nbsp;&nbsp; TERMS OF SERVICE
    </span>
</div>
""", unsafe_allow_html=True)
