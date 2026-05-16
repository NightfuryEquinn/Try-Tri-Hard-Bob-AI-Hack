import streamlit as st
import sys
from pathlib import Path

# Add project root to path
sys.path.insert(0, str(Path(__file__).parent))

from parser.sql_parser import SQLParser
from parser.name_normalizer import NameNormalizer
from generator.model_generator import ModelGenerator
from generator.test_generator import TestGenerator
from generator.report_generator import ReportGenerator
from generator.zip_packager import ZipPackager

# Page configuration
st.set_page_config(
    page_title="LegacyLink AI - Dashboard",
    page_icon="./assets/icon.png",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Initialize session state
if 'processed' not in st.session_state:
    st.session_state.processed = False
if 'parsed_tables' not in st.session_state:
    st.session_state.parsed_tables = None
if 'generated_files' not in st.session_state:
    st.session_state.generated_files = None
if 'zip_data' not in st.session_state:
    st.session_state.zip_data = None

# Custom CSS for Cyber-Metric design system from Google Stitch
st.markdown("""
<style>
    @import url('https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;600;700;900&display=swap');
    
    /* Hide default Streamlit elements */
    #MainMenu {visibility: hidden;}
    footer {visibility: hidden;}
    header {visibility: hidden;}
    
    /* Global styles */
    * {
        font-family: 'JetBrains Mono', monospace !important;
    }
    
    /* Background - Deep Space */
    .stApp {
        background-color: #0D0D0D;
    }
    
    /* Sidebar styling */
    [data-testid="stSidebar"] {
        background-color: #0D0D0D;
        border-right: 1px solid #1E293B;
        padding-top: 2rem;
    }
    
    [data-testid="stSidebar"] [data-testid="stMarkdownContainer"] {
        color: #dce4e4;
    }
    
    /* Headers - Neon Cyan */
    h1, h2, h3, h4, h5, h6 {
        color: #00F5FF !important;
        font-family: 'JetBrains Mono', monospace !important;
        font-weight: 700 !important;
        letter-spacing: -0.02em;
    }
    
    h1 {
        font-size: 48px !important;
        line-height: 56px !important;
    }
    
    h2 {
        font-size: 32px !important;
        line-height: 40px !important;
    }
    
    h3 {
        font-size: 24px !important;
        line-height: 32px !important;
    }
    
    /* Text colors */
    p, span, div, label {
        color: #dce4e4 !important;
        font-family: 'JetBrains Mono', monospace !important;
    }
    
    .muted-text {
        color: #94A3B8 !important;
    }
    
    /* Buttons - Neon Cyan primary */
    .stButton > button {
        background-color: #00F5FF !important;
        color: #0D0D0D !important;
        font-family: 'JetBrains Mono', monospace !important;
        font-weight: 700 !important;
        font-size: 12px !important;
        letter-spacing: 0.1em !important;
        text-transform: uppercase !important;
        border: none !important;
        border-radius: 0px !important;
        padding: 12px 32px !important;
        transition: all 0.3s !important;
        box-shadow: 0 0 8px rgba(0, 245, 255, 0.3) !important;
    }
    
    .stButton > button:hover {
        box-shadow: 0 0 12px rgba(0, 245, 255, 0.5) !important;
        transform: scale(1.02);
    }
    
    /* Secondary buttons */
    .stButton > button[kind="secondary"] {
        background-color: transparent !important;
        color: #00F5FF !important;
        border: 1px solid #00F5FF !important;
        box-shadow: none !important;
    }
    
    .stButton > button[kind="secondary"]:hover {
        background-color: rgba(0, 245, 255, 0.1) !important;
    }
    
    /* File uploader - Slate Surface */
    [data-testid="stFileUploader"] {
        background-color: rgba(30, 41, 59, 0.3) !important;
        border: 1px solid #1E293B !important;
        border-radius: 0px !important;
        padding: 48px 24px !important;
        min-height: 400px !important;
    }
    
    [data-testid="stFileUploader"] section {
        border: 2px dashed #00F5FF !important;
        border-radius: 0px !important;
        background-color: transparent !important;
        padding: 48px !important;
    }
    
    [data-testid="stFileUploader"] section:hover {
        box-shadow: 0 0 8px rgba(0, 245, 255, 0.3) !important;
        border-color: #00dce5 !important;
    }
    
    /* Code blocks - Terminal style */
    .stCodeBlock {
        background-color: #0D0D0D !important;
        border: 1px solid #1E293B !important;
        border-radius: 0px !important;
    }
    
    code {
        color: #10B981 !important;
        font-family: 'JetBrains Mono', monospace !important;
        font-size: 14px !important;
        line-height: 22px !important;
    }
    
    /* Info/Success boxes */
    .stAlert {
        background-color: #1E293B !important;
        border-left: 4px solid #00F5FF !important;
        border-radius: 0px !important;
        color: #dce4e4 !important;
    }
    
    /* Metrics */
    [data-testid="stMetricValue"] {
        color: #00F5FF !important;
        font-family: 'JetBrains Mono', monospace !important;
        font-weight: 700 !important;
    }
    
    [data-testid="stMetricLabel"] {
        color: #94A3B8 !important;
        font-family: 'JetBrains Mono', monospace !important;
        font-size: 12px !important;
        font-weight: 700 !important;
        letter-spacing: 0.1em !important;
        text-transform: uppercase !important;
    }
    
    /* Expander */
    .streamlit-expanderHeader {
        background-color: #1E293B !important;
        color: #00F5FF !important;
        border: 1px solid #1E293B !important;
        border-radius: 0px !important;
    }
    
    /* Custom classes */
    .cyber-card {
        background-color: rgba(30, 41, 59, 0.3);
        border: 1px solid #1E293B;
        padding: 24px;
        min-height: 400px;
    }
    
    .terminal-window {
        background-color: #0D0D0D;
        border: 1px solid #1E293B;
        padding: 0;
        min-height: 400px;
    }
    
    .terminal-header {
        background-color: #1E293B;
        border-bottom: 1px solid #1E293B;
        padding: 8px 16px;
        display: flex;
        align-items: center;
        justify-content: space-between;
    }
    
    .terminal-body {
        padding: 24px;
        font-family: 'JetBrains Mono', monospace;
        font-size: 14px;
        line-height: 22px;
    }
    
    .matrix-green {
        color: #10B981;
    }
    
    .neon-cyan {
        color: #00F5FF;
    }
</style>
""", unsafe_allow_html=True)

# Sidebar
with st.sidebar:
    st.markdown("""
    <div style='display: flex; align-items: center; gap: 12px; margin-bottom: 24px;'>
        <div style='width: 40px; height: 40px; background-color: #1E293B; border: 1px solid #1E293B; display: flex; align-items: center; justify-content: center;'>
            <span style='color: #00F5FF; font-size: 24px;'>⚡</span>
        </div>
        <div>
            <div style='color: #00F5FF; font-size: 14px; font-weight: 700;'>LEGACY_LINK</div>
            <div style='color: #94A3B8; font-size: 10px;'>V2.0_STABLE</div>
        </div>
    </div>
    """, unsafe_allow_html=True)
    
    if st.button("NEW_MODERNIZATION", use_container_width=True):
        st.session_state.processed = False
        st.session_state.parsed_tables = None
        st.session_state.generated_files = None
        st.session_state.zip_data = None
        st.rerun()
    
    st.markdown("---")
    
    st.markdown("""
    <div style='padding: 12px 0;'>
        <div style='color: #00F5FF; font-weight: 700; margin-bottom: 8px; border-right: 4px solid #00F5FF; padding-right: 8px; box-shadow: 0 0 8px rgba(0, 245, 255, 0.3);'>
            ⚡ Modernize
        </div>
        <div style='color: #94A3B8; padding: 8px 0; cursor: pointer;'>📜 History</div>
        <div style='color: #94A3B8; padding: 8px 0; cursor: pointer;'>📄 Documentation</div>
        <div style='color: #94A3B8; padding: 8px 0; cursor: pointer;'>💬 Support</div>
    </div>
    """, unsafe_allow_html=True)

# Main content
st.markdown("""
<div style='text-align: center; margin-top: 32px; margin-bottom: 64px;'>
    <h1 style='margin-bottom: 16px;'>
        IBM Bob-assisted<br>
        <span style='color: #00F5FF;'>legacy SQL schema modernization</span>
    </h1>
    <p style='color: #94A3B8; font-size: 16px; line-height: 24px; max-width: 800px; margin: 0 auto 32px;'>
        Instantly translate archaic database structures into pristine, modern architectures. Upload your legacy SQL files and let AI handle the heavy lifting of schema normalization, type mapping, and constraint generation.
    </p>
</div>
""", unsafe_allow_html=True)

# Process uploaded file
def process_sql_file(sql_content: str):
    """Process SQL file and generate all outputs"""
    try:
        # Parse SQL
        parser = SQLParser()
        tables = parser.parse_sql_file(sql_content)
        
        if not tables:
            st.error("❌ No tables found in SQL file. Please check the file format.")
            return None
        
        # Normalize names
        normalizer = NameNormalizer()
        for table in tables:
            table['clean_name'] = normalizer.normalize_table_name(table['original_name'])
            table['table_name'] = normalizer.normalize_table_name_to_tablename(table['clean_name'])
            
            for column in table['columns']:
                column['clean_name'] = normalizer.normalize_column_name(column['original_name'])
        
        # Generate models
        model_gen = ModelGenerator()
        models_code = model_gen.generate_models(tables)
        database_code = model_gen.generate_database_file()
        
        # Generate tests
        test_gen = TestGenerator()
        tests_code = test_gen.generate_tests(tables)
        
        # Generate reports
        report_gen = ReportGenerator()
        readme = report_gen.generate_readme(tables)
        modernization_report = report_gen.generate_modernization_report(
            tables,
            normalizer.get_transformation_log()
        )
        requirements = report_gen.generate_requirements()
        
        # Package into ZIP
        files = {
            'models.py': models_code,
            'database.py': database_code,
            'test_models.py': tests_code,
            'README.md': readme,
            'modernization_report.md': modernization_report,
            'requirements.txt': requirements
        }
        
        packager = ZipPackager()
        zip_data = packager.create_zip(files)
        
        return {
            'tables': tables,
            'files': files,
            'zip_data': zip_data,
            'table_count': len(tables),
            'column_count': sum(len(t['columns']) for t in tables),
            'transformation_count': len(normalizer.get_transformation_log())
        }
        
    except Exception as e:
        st.error(f"❌ Error processing SQL file: {str(e)}")
        return None

# Main UI
if not st.session_state.processed:
    # Upload section
    col1, col2 = st.columns(2)
    
    with col1:
        st.markdown("""
        <div class='cyber-card' style='text-align: center; position: relative; cursor: pointer;'>
            <div style='position: absolute; inset: 0; background-image: url("data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMjAiIGhlaWdodD0iMjAiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+PGNpcmNsZSBjeD0iMSIgY3k9IjEiIHI9IjEiIGZpbGw9IiMzMzQxNTUiLz48L3N2Zz4="); opacity: 0.2;'></div>
            <div style='position: relative; z-index: 10;'>
                <div style='width: 80px; height: 80px; border-radius: 50%; background-color: #1E293B; border: 2px dashed #00F5FF; display: flex; align-items: center; justify-content: center; margin: 0 auto 24px; font-size: 40px;'>
                    ☁️
                </div>
                <h3 style='margin-bottom: 8px;'>Drag & Drop SQL File</h3>
                <p style='color: #94A3B8; font-size: 14px; margin-bottom: 24px;'>
                    Supports .sql, .ddl, or plain text schema dumps from legacy systems.
                </p>
                <div style='display: flex; align-items: center; justify-content: center; gap: 8px; margin-bottom: 24px;'>
                    <span style='width: 48px; height: 1px; background-color: #1E293B;'></span>
                    <span style='color: #94A3B8; font-size: 12px; letter-spacing: 0.1em;'>OR</span>
                    <span style='width: 48px; height: 1px; background-color: #1E293B;'></span>
                </div>
            </div>
        </div>
        """, unsafe_allow_html=True)
        
        uploaded_file = st.file_uploader("BROWSE FILES", type=["sql", "ddl", "txt"], label_visibility="collapsed")
        
        if uploaded_file is not None:
            if st.button("🚀 PROCESS SQL FILE", use_container_width=True):
                with st.spinner("Processing..."):
                    sql_content = uploaded_file.read().decode('utf-8')
                    result = process_sql_file(sql_content)
                    
                    if result:
                        st.session_state.processed = True
                        st.session_state.parsed_tables = result['tables']
                        st.session_state.generated_files = result['files']
                        st.session_state.zip_data = result['zip_data']
                        st.session_state.stats = {
                            'table_count': result['table_count'],
                            'column_count': result['column_count'],
                            'transformation_count': result['transformation_count']
                        }
                        st.rerun()
    
    with col2:
        st.markdown("""
        <div class='terminal-window'>
            <div class='terminal-header'>
                <div style='display: flex; gap: 8px;'>
                    <div style='width: 12px; height: 12px; border-radius: 50%; background-color: #1E293B; border: 1px solid #1E293B;'></div>
                    <div style='width: 12px; height: 12px; border-radius: 50%; background-color: #1E293B; border: 1px solid #1E293B;'></div>
                    <div style='width: 12px; height: 12px; border-radius: 50%; background-color: #1E293B; border: 1px solid #1E293B;'></div>
                </div>
                <span style='color: #94A3B8; font-size: 12px; letter-spacing: 0.1em;'>preview_terminal.sh</span>
                <div style='width: 16px;'></div>
            </div>
            <div class='terminal-body'>
                <div style='color: #94A3B8; margin-bottom: 16px;'>// Waiting for input...</div>
                <div class='matrix-green' style='margin-bottom: 4px;'>> SYSTEM_READY</div>
                <div class='matrix-green' style='margin-bottom: 4px;'>> IBM_BOB_MODEL_LOADED</div>
                <div class='matrix-green' style='margin-bottom: 24px;'>> AWAITING_LEGACY_SCHEMA</div>
                <div style='margin-top: auto; opacity: 0.5; padding-top: 100px;'>
                    <div style='display: flex; align-items: center; gap: 8px; margin-bottom: 8px;'>
                        <span class='neon-cyan' style='font-size: 14px;'>⚙️</span>
                        <span style='color: #94A3B8; font-size: 12px;'>Processing Engine Idle</span>
                    </div>
                    <div style='width: 100%; background-color: #1E293B; height: 4px;'>
                        <div style='background-color: #00F5FF; height: 100%; width: 0%;'></div>
                    </div>
                </div>
            </div>
        </div>
        """, unsafe_allow_html=True)

else:
    # Results section
    st.success("✅ SQL schema successfully modernized!")
    
    # Metrics
    col1, col2, col3 = st.columns(3)
    with col1:
        st.metric("TABLES PROCESSED", st.session_state.stats['table_count'])
    with col2:
        st.metric("COLUMNS NORMALIZED", st.session_state.stats['column_count'])
    with col3:
        st.metric("TRANSFORMATIONS", st.session_state.stats['transformation_count'])
    
    st.markdown("<br>", unsafe_allow_html=True)
    
    # Tabs for different views
    tab1, tab2, tab3, tab4 = st.tabs(["📊 Schema Overview", "💻 Generated Models", "🧪 Test Suite", "📄 Reports"])
    
    with tab1:
        st.subheader("Parsed Schema")
        for table in st.session_state.parsed_tables:
            with st.expander(f"**{table['original_name']}** → **{table['clean_name']}**"):
                st.write(f"**Database Table:** `{table['table_name']}`")
                st.write(f"**Columns:** {len(table['columns'])}")
                
                col_data = []
                for col in table['columns']:
                    col_data.append({
                        'Original': col['original_name'],
                        'Clean': col['clean_name'],
                        'Type': col['type'],
                        'PK': '✓' if col.get('primary_key') else '',
                        'Nullable': '✓' if col.get('nullable') else ''
                    })
                st.table(col_data)
    
    with tab2:
        st.subheader("Generated SQLAlchemy Models")
        st.code(st.session_state.generated_files['models.py'], language='python')
        
        with st.expander("View database.py"):
            st.code(st.session_state.generated_files['database.py'], language='python')
    
    with tab3:
        st.subheader("Generated Test Suite")
        st.code(st.session_state.generated_files['test_models.py'], language='python')
    
    with tab4:
        st.subheader("Documentation")
        
        readme_tab, report_tab = st.tabs(["README.md", "Modernization Report"])
        
        with readme_tab:
            st.markdown(st.session_state.generated_files['README.md'])
        
        with report_tab:
            st.markdown(st.session_state.generated_files['modernization_report.md'])
    
    # Download button
    st.markdown("<br>", unsafe_allow_html=True)
    st.download_button(
        label="⬇️ DOWNLOAD COMPLETE PROJECT (ZIP)",
        data=st.session_state.zip_data,
        file_name="legacylink_generated_project.zip",
        mime="application/zip",
        use_container_width=True
    )

# Footer
st.markdown("<br><br>", unsafe_allow_html=True)
st.markdown("""
<div style='position: fixed; bottom: 0; left: 0; right: 0; background-color: rgba(13, 13, 13, 0.9); backdrop-filter: blur(12px); border-top: 1px solid #1E293B; padding: 12px 40px; display: flex; justify-content: space-between; align-items: center; z-index: 1000; margin-left: 250px;'>
    <span class='matrix-green' style='font-size: 12px; letter-spacing: 0.1em;'>SYSTEM_READY | IBM_BOB_POWERED</span>
    <div style='display: flex; gap: 24px;'>
        <span style='color: #94A3B8; font-size: 12px;'>Made with IBM Bob</span>
    </div>
</div>
""", unsafe_allow_html=True)
