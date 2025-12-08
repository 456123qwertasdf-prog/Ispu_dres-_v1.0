# GitHub Authentication Setup Guide

## Step 1: Create a Personal Access Token (PAT)

1. Go to GitHub.com and sign in
2. Click your profile picture (top right) → **Settings**
3. Scroll down in the left sidebar → **Developer settings**
4. Click **Personal access tokens** → **Tokens (classic)**
5. Click **Generate new token** → **Generate new token (classic)**
6. Give it a name (e.g., "LSPU DRES Push Token")
7. Set expiration (choose your preference, or "No expiration" for convenience)
8. Select scopes - **check these boxes:**
   - ✅ **repo** (Full control of private repositories)
     - This includes: repo:status, repo_deployment, public_repo, repo:invite, security_events
9. Click **Generate token** at the bottom
10. **IMPORTANT:** Copy the token immediately - you won't be able to see it again!
    - It will look like: `ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`

## Step 2: Use the Token

When you push to GitHub, use your token as the password:
- Username: Your GitHub username (456123qwertasdf-prog)
- Password: The Personal Access Token you just created

## Alternative: Store Credentials (Optional)

You can configure Git to remember your credentials so you don't have to enter them every time.

