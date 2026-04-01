"""
Single-run Gmail AI Sender
- Composes email with OpenAI GPT
- Sends via Gmail API
- First run will open a browser to authorize Gmail
"""

import os
import base64
from email.mime.text import MIMEText

import openai
from googleapiclient.discovery import build
from google_auth_oauthlib.flow import InstalledAppFlow
from google.oauth2.credentials import Credentials

# -----------------------------
# CONFIGURATION
# -----------------------------
SCOPES = ['https://www.googleapis.com/auth/gmail.send']
CREDENTIALS_FILE = 'credentials.json'  # Download from Google Cloud Console
TOKEN_FILE = 'token.json'

# -----------------------------
# PROMPT USER FOR INPUT
# -----------------------------
recipient = input("Enter recipient email: ")
subject = input("Enter email subject: ")
prompt_text = input("Enter prompt for AI to compose email body: ")

# -----------------------------
# OPENAI CONFIG
# -----------------------------
openai.api_key = os.environ.get("OPENAI_API_KEY")
if not openai.api_key:
    raise ValueError("Set your OPENAI_API_KEY as environment variable.")

# Generate email body using AI
response = openai.ChatCompletion.create(
    model="gpt-5-mini",
    messages=[{"role": "user", "content": prompt_text}]
)
email_body = response['choices'][0]['message']['content']
print("\n--- AI Generated Email ---\n")
print(email_body)
print("\n--------------------------\n")

# -----------------------------
# GMAIL AUTHENTICATION
# -----------------------------
creds = None
if os.path.exists(TOKEN_FILE):
    creds = Credentials.from_authorized_user_file(TOKEN_FILE, SCOPES)

if not creds or not creds.valid:
    if creds and creds.expired and creds.refresh_token:
        creds.refresh(Request())
    else:
        flow = InstalledAppFlow.from_client_secrets_file(CREDENTIALS_FILE, SCOPES)
        creds = flow.run_local_server(port=0)
    with open(TOKEN_FILE, 'w') as token:
        token.write(creds.to_json())

service = build('gmail', 'v1', credentials=creds)

# -----------------------------
# CREATE AND SEND EMAIL
# -----------------------------
message = MIMEText(email_body)
message['to'] = recipient
message['subject'] = subject
raw_message = base64.urlsafe_b64encode(message.as_bytes()).decode()

try:
    service.users().messages().send(userId='me', body={'raw': raw_message}).execute()
    print(f"Email successfully sent to {recipient}")
except Exception as e:
    print("Failed to send email:", e)
