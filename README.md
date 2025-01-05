AWS IAM Key Management Tool
===========================

The AWS IAM Key Management Tool is a Bash script designed to simplify the management of AWS IAM user access keys. It provides an interactive, secure, and efficient way to manage access keys directly from the command line.

Features
--------
- List Access Keys – View all access keys for a specified IAM user.
- Create New Access Key – Generate a new access key while respecting AWS key limits.
- Deactivate Access Key – Disable active keys to enhance security.
- Activate Access Key – Reactivate previously disabled access keys.
- Delete Access Key – Permanently remove inactive access keys.
- Deactivate and Delete – Deactivate and delete active keys in one operation.
- Interactive Interface – Use `fzf` for easy key selection.
- Logging – Actions are logged with timestamps for auditing purposes.

Prerequisites
-------------
Ensure the following tools are installed:
- AWS CLI – Manage AWS services from the command line.
- jq – Process JSON outputs from AWS CLI.
- fzf – Fuzzy finder for interactive selection.

Install Required Tools:
-----------------------
# AWS CLI
sudo apt install awscli    # Ubuntu/Debian
brew install awscli        # macOS

# jq
sudo apt install jq        # Ubuntu/Debian
brew install jq            # macOS

# fzf
sudo apt install fzf       # Ubuntu/Debian
brew install fzf           # macOS

Installation
------------
1. Clone the Repository:
git clone https://github.com/yourusername/aws-iam-key-management-tool.git
cd aws-iam-key-management-tool

2. Configure AWS CLI:
aws configure
Ensure the IAM user has the following permissions:
- iam:ListAccessKeys
- iam:CreateAccessKey
- iam:UpdateAccessKey
- iam:DeleteAccessKey
- iam:GetUser

Usage
-----
1. Run the Script:
bash aws_key_manager.sh

2. Follow the Prompts:
- Enter the IAM username.
- Select an option from the interactive menu.
- Confirm actions when prompted.

Logging and Key Storage
-----------------------
- Logs – Stored in the `logs/` directory (<Action>_<Date>_<Time>.txt).
- Generated Keys – Stored in the `keys/` directory (Generated-Keys_<Date>_<Time>.txt).

Security Considerations
-----------------------
- AWS limits IAM users to two active access keys. This tool checks and enforces that limit.
- Store generated keys securely to prevent unauthorized access.
- Use IAM permissions following the principle of least privilege.

Contributing
------------
Contributions are welcome! Fork the repository and submit a pull request.

Acknowledgments
---------------
Inspired by AWS IAM best practices and secure key management techniques.
