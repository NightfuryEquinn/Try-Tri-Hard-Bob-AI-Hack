# IBM Cloudant Setup Guide for LegacyLink AI

This guide walks you through setting up IBM Cloudant NoSQL database for session history tracking in LegacyLink AI.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Step 1: Create IBM Cloud Account](#step-1-create-ibm-cloud-account)
- [Step 2: Create Cloudant Service Instance](#step-2-create-cloudant-service-instance)
- [Step 3: Generate Service Credentials](#step-3-generate-service-credentials)
- [Step 4: Configure LegacyLink AI](#step-4-configure-legacylink-ai)
- [Step 5: Verify Connection](#step-5-verify-connection)
- [Troubleshooting](#troubleshooting)
- [Security Best Practices](#security-best-practices)

---

## Overview

IBM Cloudant is a fully managed NoSQL database service that LegacyLink AI uses to store modernization session history. This feature is **optional** - the application works perfectly without it, but enabling it provides:

- **Session History**: Track all SQL modernization sessions
- **User Analytics**: View processing statistics across sessions
- **Audit Trail**: Maintain records of transformations applied
- **Session Replay**: Retrieve and review previous modernizations

---

## Prerequisites

- IBM Cloud account (free tier available)
- LegacyLink AI application installed
- Basic command line knowledge

---

## Step 1: Create IBM Cloud Account

1. **Visit IBM Cloud**: Go to [https://cloud.ibm.com/registration](https://cloud.ibm.com/registration)

2. **Sign Up**: Create a free IBM Cloud account
   - Enter your email address
   - Verify your email
   - Complete the registration form

3. **Login**: Access the IBM Cloud dashboard at [https://cloud.ibm.com](https://cloud.ibm.com)

> **Note**: IBM Cloud offers a free tier that includes Cloudant Lite plan with 1GB storage and 20 lookups/sec.

---

## Step 2: Create Cloudant Service Instance

1. **Navigate to Catalog**:
   - Click **Catalog** in the top navigation
   - Search for "Cloudant"
   - Select **Cloudant** from the results

2. **Configure Service**:
   - **Region**: Select your preferred region (e.g., `us-south`, `eu-gb`)
   - **Pricing Plan**: Select **Lite** (free) or **Standard** (paid)
   - **Service Name**: Enter a name (e.g., `legacylink-cloudant`)
   - **Resource Group**: Select `Default` or create a new one

3. **Create Instance**:
   - Review your configuration
   - Click **Create**
   - Wait for provisioning to complete (usually < 1 minute)

4. **Access Dashboard**:
   - Click on your newly created Cloudant instance
   - You'll see the service dashboard

---

## Step 3: Generate Service Credentials

1. **Open Service Credentials**:
   - In your Cloudant instance dashboard
   - Click **Service credentials** in the left sidebar

2. **Create New Credential**:
   - Click **New credential** button
   - **Name**: Enter `legacylink-credentials`
   - **Role**: Select **Manager** (full access)
   - Click **Add**

3. **View Credentials**:
   - Click **View credentials** next to your new credential
   - You'll see a JSON object with connection details

4. **Copy Required Values**:
   ```json
   {
     "apikey": "YOUR_API_KEY_HERE",
     "url": "https://YOUR_INSTANCE.cloudantnosqldb.appdomain.cloud",
     ...
   }
   ```
   
   Copy these two values:
   - `apikey`: Your IAM API key
   - `url`: Your Cloudant service URL

> **Security Warning**: Keep these credentials secure! Never commit them to version control.

---

## Step 4: Configure LegacyLink AI

### Option A: Using Environment Variables (Recommended)

1. **Create `.env` file** in your project root:
   ```bash
   # Navigate to project directory
   cd /path/to/Try-Tri-Hard-Bob-AI-Hack
   
   # Copy example file
   cp .env.example .env
   ```

2. **Edit `.env` file**:
   ```bash
   # IBM Cloudant Configuration
   CLOUDANT_URL=https://YOUR_INSTANCE.cloudantnosqldb.appdomain.cloud
   CLOUDANT_APIKEY=YOUR_API_KEY_HERE
   CLOUDANT_DATABASE_NAME=legacylink_history
   
   # Enable history tracking
   ENABLE_HISTORY_TRACKING=true
   ```

3. **Replace placeholders**:
   - Replace `YOUR_INSTANCE` with your actual instance name
   - Replace `YOUR_API_KEY_HERE` with your actual API key
   - Keep `CLOUDANT_DATABASE_NAME` as `legacylink_history` (or customize)

### Option B: Using System Environment Variables

**Windows (PowerShell)**:
```powershell
$env:CLOUDANT_URL="https://YOUR_INSTANCE.cloudantnosqldb.appdomain.cloud"
$env:CLOUDANT_APIKEY="YOUR_API_KEY_HERE"
$env:CLOUDANT_DATABASE_NAME="legacylink_history"
$env:ENABLE_HISTORY_TRACKING="true"
```

**Linux/macOS (Bash)**:
```bash
export CLOUDANT_URL="https://YOUR_INSTANCE.cloudantnosqldb.appdomain.cloud"
export CLOUDANT_APIKEY="YOUR_API_KEY_HERE"
export CLOUDANT_DATABASE_NAME="legacylink_history"
export ENABLE_HISTORY_TRACKING="true"
```

---

## Step 5: Verify Connection

1. **Run Tests**:
   ```bash
   # Run Cloudant integration tests
   pytest tests/test_cloudant_integration.py -v
   ```
   
   Expected output:
   ```
   ============================= test session starts =============================
   ...
   tests/test_cloudant_integration.py::test_cloudant_config_validation PASSED
   tests/test_cloudant_integration.py::test_save_modernization_session PASSED
   ...
   ============================= 12 passed in 0.46s ==============================
   ```

2. **Start Application**:
   ```bash
   streamlit run app.py
   ```

3. **Check Startup Messages**:
   - Look for Cloudant initialization messages in the console
   - No errors should appear related to Cloudant

4. **Test Session Saving**:
   - Upload a sample SQL file
   - Click "PROCESS SQL FILE"
   - Look for success message: "✅ Session saved to history (ID: ...)"

5. **Verify in Cloudant Dashboard**:
   - Go to IBM Cloud dashboard
   - Open your Cloudant instance
   - Click **Launch Dashboard**
   - Select `legacylink_history` database
   - You should see session documents

---

## Troubleshooting

### Issue: "Could not save to history" Warning

**Possible Causes**:
- Invalid API key or URL
- Network connectivity issues
- Database doesn't exist (should auto-create)

**Solutions**:
1. Verify credentials in `.env` file
2. Check network connection
3. Ensure API key has Manager role
4. Check Cloudant service status in IBM Cloud

### Issue: Database Not Created Automatically

**Solution**:
1. Manually create database in Cloudant dashboard:
   - Click **Create Database**
   - Name: `legacylink_history`
   - Partitioning: **Non-partitioned**
   - Click **Create**

### Issue: "Authentication failed" Error

**Solution**:
1. Regenerate service credentials:
   - Delete old credential
   - Create new credential with Manager role
   - Update `.env` file with new values

### Issue: Application Works But No History Saved

**Check**:
1. Verify `ENABLE_HISTORY_TRACKING=true` in `.env`
2. Ensure `.env` file is in project root
3. Restart application after changing `.env`
4. Check console for warning messages

### Issue: Rate Limit Exceeded (Lite Plan)

**Symptoms**: "429 Too Many Requests" errors

**Solutions**:
- Upgrade to Standard plan for higher limits
- Reduce processing frequency
- Implement request throttling

---

## Security Best Practices

### 1. Protect Credentials

✅ **DO**:
- Store credentials in `.env` file (not committed to git)
- Use environment variables in production
- Rotate API keys regularly
- Use IAM roles with minimum required permissions

❌ **DON'T**:
- Commit `.env` file to version control
- Share credentials in chat/email
- Use root/admin credentials
- Hardcode credentials in source code

### 2. Network Security

- Use HTTPS only (Cloudant enforces this)
- Restrict access by IP if possible
- Use VPC for production deployments
- Enable audit logging in IBM Cloud

### 3. Data Privacy

- Review data retention policies
- Implement data encryption at rest (enabled by default)
- Consider GDPR/compliance requirements
- Document what data is stored

### 4. Access Control

- Use separate credentials for dev/prod
- Implement least privilege principle
- Regularly audit access logs
- Revoke unused credentials

---

## Database Schema

The `legacylink_history` database stores documents with this structure:

```json
{
  "_id": "session_2026-05-17T02:43:00.000000Z_abc12345",
  "type": "modernization_session",
  "user_id": "user-identifier",
  "session_id": "abc12345",
  "timestamp": "2026-05-17T02:43:00.000000Z",
  "input": {
    "filename": "legacy_schema.sql",
    "file_size": 1024,
    "upload_timestamp": "2026-05-17T02:43:00.000000Z"
  },
  "processing": {
    "table_count": 3,
    "column_count": 25,
    "transformation_count": 50,
    "processing_time_ms": 500
  },
  "output": {
    "tables": [...],
    "generated_files": [...]
  },
  "transformations": [...],
  "metadata": {
    "app_version": "1.0.0",
    "bob_assisted": true,
    "success": true
  }
}
```

---

## Cost Estimation

### Lite Plan (Free)
- **Storage**: 1 GB
- **Throughput**: 20 lookups/sec, 10 writes/sec
- **Cost**: $0/month
- **Best for**: Development, testing, small projects

### Standard Plan (Paid)
- **Storage**: $1.00/GB/month
- **Throughput**: Provisioned capacity units
- **Cost**: Variable based on usage
- **Best for**: Production, high-volume applications

**Typical Usage for LegacyLink AI**:
- Each session: ~5-50 KB
- 100 sessions/day: ~2.5 MB/day = ~75 MB/month
- **Estimated cost**: Free tier sufficient for most use cases

---

## Next Steps

1. ✅ Cloudant is configured and working
2. 📖 Read [CLOUDANT_INTEGRATION.md](CLOUDANT_INTEGRATION.md) for technical details
3. 🧪 Run integration tests regularly
4. 📊 Monitor usage in IBM Cloud dashboard
5. 🔒 Review security settings periodically

---

## Support

- **IBM Cloud Support**: [https://cloud.ibm.com/unifiedsupport/supportcenter](https://cloud.ibm.com/unifiedsupport/supportcenter)
- **Cloudant Documentation**: [https://cloud.ibm.com/docs/Cloudant](https://cloud.ibm.com/docs/Cloudant)
- **LegacyLink AI Issues**: [GitHub Issues](https://github.com/your-repo/issues)

---

**Made with IBM Bob** 🤖