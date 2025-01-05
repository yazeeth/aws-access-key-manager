#!/bin/bash

AWS_USER=""

# Welcome Banner
welcome_banner() {
    clear
    echo -e "\e[1;34m=========================================\e[0m"
    echo -e "\e[1;32m      AWS IAM Key Management Tool\e[0m"
    echo -e "\e[1;34m=========================================\e[0m"
    echo -e "\e[1;33mManage AWS IAM Access Keys securely and efficiently.\e[0m"
    echo ""
    echo -e "\e[1;36mAvailable Actions:\e[0m"
    echo -e "\e[1;37m- List AWS IAM access keys\e[0m"
    echo -e "\e[1;37m- Create new IAM access key\e[0m"
    echo -e "\e[1;37m- Deactivate active access keys\e[0m"
    echo -e "\e[1;37m- Delete inactive access keys\e[0m"
    echo -e "\e[1;37m- Activate inactive access keys\e[0m"
    echo -e "\e[1;37m- Deactivate and delete access keys\e[0m"
    echo -e "\e[1;34m=========================================\e[0m"
    echo -e "\e[1;35mPress Enter to continue...\e[0m"
    read
    clear
}

# IAM User Prompt
prompt_for_username() {
    while true; do
        echo -e "\e[1;33mEnter the IAM username to manage access keys:\e[0m"
        read -p "IAM Username: " AWS_USER
        if [ -z "$AWS_USER" ]; then
            echo -e "\e[1;31mUsername cannot be empty. Please try again.\e[0m"
        else
            aws iam get-user --user-name "$AWS_USER" > /dev/null 2>&1
            if [ $? -eq 0 ]; then
                echo -e "\e[1;32mUser $AWS_USER found.\e[0m"
                break
            else
                echo -e "\e[1;31mUser $AWS_USER not found. Please check and try again.\e[0m"
            fi
        fi
    done
}

# Main Menu
menu() {
    while true; do
        MENU_OPTION=$(printf "List all AWS access keys\nCreate new access key\nDeactivate active access keys\nDelete inactive access keys\nActivate inactive access keys\nDeactivate and delete access keys\nBack to IAM user selection\nExit" | \
        fzf --height 10 --border --prompt="Select an option for IAM user $AWS_USER: ")

        case $MENU_OPTION in
            "List all AWS access keys") list_access_keys ;;
            "Create new access key") create_new_key ;;
            "Deactivate active access keys") deactivate_key ;;
            "Delete inactive access keys") delete_key ;;
            "Activate inactive access keys") activate_key ;;
            "Deactivate and delete access keys") deactivate_and_delete_key ;;
            "Back to IAM user selection") prompt_for_username ;;
            "Exit") echo -e "\e[1;35mExiting... Goodbye!\e[0m"; exit 0 ;;
            *) echo -e "\e[1;31mInvalid option. Please try again.\e[0m" ;;
        esac
    done
}

# Generate Log File Names
generate_filename() {
    local action=$1
    local datetime=$(date +"%Y-%m-%d_%H-%M-%S")
    echo "${action}_${datetime}.txt"
}

# Log Actions
log_action() {
    local action=$1
    local key_id=$2
    local status=$3
    local file_name=$(generate_filename "$action")

    {
        echo "IAM User: $AWS_USER"
        echo "Action: $action"
        echo "AccessKeyId: $key_id"
        echo "Status: $status"
        echo "Timestamp: $(date +"%Y-%m-%d %H:%M:%S")"
        echo "--------------------------------------"
    } >> "$file_name"

    echo -e "\e[1;32mAction logged to $file_name\e[0m"
}

# List Access Keys (with Error Handling and Formatting)
list_access_keys() {
    echo "Fetching all access keys for IAM user $AWS_USER..."

    # Fetch access keys and handle errors
    KEYS=$(aws iam list-access-keys --user-name "$AWS_USER" 2>&1)

    if echo "$KEYS" | grep -q "error"; then
        echo -e "\e[1;31mFailed to retrieve access keys:\e[0m $KEYS"
        return
    fi

    # Extract and format key details
    KEY_LIST=$(echo "$KEYS" | jq -r '.AccessKeyMetadata[] | "\(.AccessKeyId) - Created: \(.CreateDate) - Status: \(.Status)"')

    if [ -z "$KEY_LIST" ]; then
        echo -e "\e[1;33mNo access keys found for IAM user $AWS_USER.\e[0m"
        return
    fi

    echo -e "\e[1;36mAvailable Access Keys:\e[0m"
    echo "$KEY_LIST" | fzf --height 10 --border --prompt="Select an access key (ESC to exit): "
}

# Create New Access Key (with Warnings and Limit Check)
create_new_key() {
    echo "Checking existing access keys for IAM user $AWS_USER..."
    KEY_COUNT=$(aws iam list-access-keys --user-name "$AWS_USER" | jq '.AccessKeyMetadata | length')

    if [ "$KEY_COUNT" -ge 2 ]; then
        echo -e "\e[1;31mWARNING: IAM users can only have two active access keys at a time.\e[0m"
        echo -e "\e[1;33mYou must delete or deactivate an existing key before creating a new one.\e[0m"
        return
    fi

    echo "Creating new access key for IAM user $AWS_USER..."
    NEW_KEYS=$(aws iam create-access-key --user-name "$AWS_USER" 2>&1)

    if echo "$NEW_KEYS" | grep -q "error"; then
        echo -e "\e[1;31mFailed to create new access key:\e[0m $NEW_KEYS"
        return
    fi

    NEW_ACCESS_KEY=$(echo "$NEW_KEYS" | jq -r '.AccessKey.AccessKeyId')
    NEW_SECRET_KEY=$(echo "$NEW_KEYS" | jq -r '.AccessKey.SecretAccessKey')
    
    # Filename format: Generated-Keys_<Date>_<Time>.txt
    FILE_NAME="Generated-Keys_$(date +"%Y-%m-%d_%H-%M-%S").txt"
    {
        echo "AccessKeyId=$NEW_ACCESS_KEY"
        echo "SecretAccessKey=$NEW_SECRET_KEY"
    } > "$FILE_NAME"
    
    echo -e "\e[1;32mNew key created successfully.\e[0m"
    echo -e "\e[1;33mAccess key details saved to:\e[0m $FILE_NAME"
    log_action "Create" "$NEW_ACCESS_KEY" "Active"
}

# Deactivate Active Access Keys (with Enhanced Warning)
deactivate_key() {
    echo "Fetching active access keys for IAM user $AWS_USER..."
    ACTIVE_KEYS=$(aws iam list-access-keys --user-name "$AWS_USER" | jq -r '.AccessKeyMetadata[] | select(.Status=="Active") | "\(.AccessKeyId) - Created on \(.CreateDate)"')

    SELECTED_KEY=$(echo "$ACTIVE_KEYS" | fzf --height 10 --prompt="Select active key to deactivate: ")
    if [ -z "$SELECTED_KEY" ]; then
        echo "No key selected. Returning to menu."
        return
    fi

    ACCESS_KEY_ID=$(echo "$SELECTED_KEY" | awk '{print $1}')

    echo -e "\e[1;31mWARNING: You are about to DEACTIVATE the active access key: $ACCESS_KEY_ID\e[0m"
    echo -e "\e[1;33mDeactivating an active key may interrupt services or applications that rely on it.\e[0m"
    echo -e "\e[1;33mEnsure that this key is no longer in use or is replaced with a new key.\e[0m"
    read -p "Are you sure you want to continue? (y/n): " CONFIRM

    if [[ "$CONFIRM" == "y" ]]; then
        echo "Deactivating access key $ACCESS_KEY_ID..."
        aws iam update-access-key --access-key-id "$ACCESS_KEY_ID" --status Inactive --user-name "$AWS_USER"
        
        if [ $? -eq 0 ]; then
            log_action "Deactivate" "$ACCESS_KEY_ID" "Inactive"
            echo -e "\e[1;32mKey $ACCESS_KEY_ID has been deactivated successfully.\e[0m"
        else
            echo -e "\e[1;31mFailed to deactivate key $ACCESS_KEY_ID. Please check for errors.\e[0m"
        fi
    else
        echo "Operation canceled. Access key $ACCESS_KEY_ID remains active."
    fi
}


# Delete inactive access keys (with Warning)
delete_key() {
    echo "Fetching inactive access keys for IAM user $AWS_USER..."
    INACTIVE_KEYS=$(aws iam list-access-keys --user-name "$AWS_USER" | jq -r '.AccessKeyMetadata[] | select(.Status=="Inactive") | "\(.AccessKeyId) - Created on \(.CreateDate)"')

    SELECTED_KEY=$(echo "$INACTIVE_KEYS" | fzf --height 10 --prompt="Select inactive key to delete: ")
    if [ -z "$SELECTED_KEY" ]; then
        echo "No key selected. Returning to menu."
        return
    fi

    ACCESS_KEY_ID=$(echo "$SELECTED_KEY" | awk '{print $1}')

    echo -e "\e[1;31mWARNING: You are about to DELETE the inactive access key: $ACCESS_KEY_ID\e[0m"
    echo -e "\e[1;33mThis action is irreversible. Once deleted, the key cannot be recovered.\e[0m"
    read -p "Are you sure you want to continue? (y/n): " CONFIRM

    if [[ "$CONFIRM" != "y" ]]; then
        echo "Operation canceled."
        return
    fi

    echo "Deleting inactive access key $ACCESS_KEY_ID..."
    aws iam delete-access-key --access-key-id "$ACCESS_KEY_ID" --user-name "$AWS_USER"
    log_action "Delete" "$ACCESS_KEY_ID" "Deleted"
    echo -e "\e[1;32mKey $ACCESS_KEY_ID has been deleted.\e[0m"
}

# Activate inactive access keys
activate_key() {
    echo "Fetching inactive access keys for user $AWS_USER..."
    INACTIVE_KEYS=$(aws iam list-access-keys --user-name "$AWS_USER" | jq -r '.AccessKeyMetadata[] | select(.Status=="Inactive") | "\(.AccessKeyId) - Created on \(.CreateDate)"')

    SELECTED_KEY=$(echo "$INACTIVE_KEYS" | fzf --height 10 --prompt="Select inactive key to activate: ")
    if [ -z "$SELECTED_KEY" ]; then
        echo "No key selected. Returning to menu."
        return
    fi

    ACCESS_KEY_ID=$(echo "$SELECTED_KEY" | awk '{print $1}')
    aws iam update-access-key --access-key-id "$ACCESS_KEY_ID" --status Active --user-name "$AWS_USER"
    log_action "Activate" "$ACCESS_KEY_ID" "Active"
    echo "Key $ACCESS_KEY_ID has been activated."
}

# Deactivate and delete keys (both active and inactive)
deactivate_and_delete_key() {
    echo "Fetching all access keys for IAM user $AWS_USER..."
    KEYS=$(aws iam list-access-keys --user-name "$AWS_USER" | jq -r '.AccessKeyMetadata[] | "\(.AccessKeyId) - Created on \(.CreateDate) - Status: \(.Status)"')

    SELECTED_KEY=$(echo "$KEYS" | fzf --height 10 --prompt="Select key to deactivate and delete: ")
    if [ -z "$SELECTED_KEY" ]; then
        echo "No key selected. Returning to menu."
        return
    fi

    ACCESS_KEY_ID=$(echo "$SELECTED_KEY" | awk '{print $1}')
    KEY_STATUS=$(echo "$SELECTED_KEY" | awk '{print $NF}')

    echo -e "\e[1;31mWARNING: You are about to DEACTIVATE and DELETE access key: $ACCESS_KEY_ID\e[0m"
    echo -e "\e[1;33mThis action is irreversible. Proceed with caution.\e[0m"
    read -p "Are you sure you want to continue? (y/n): " CONFIRM

    if [[ "$CONFIRM" != "y" ]]; then
        echo "Operation canceled."
        return
    fi

    if [ "$KEY_STATUS" == "Active" ]; then
        echo "Deactivating access key $ACCESS_KEY_ID..."
        aws iam update-access-key --access-key-id "$ACCESS_KEY_ID" --status Inactive --user-name "$AWS_USER"
        log_action "Deactivate" "$ACCESS_KEY_ID" "Inactive"
        echo -e "\e[1;32mKey $ACCESS_KEY_ID has been deactivated.\e[0m"
    fi

    echo "Deleting access key $ACCESS_KEY_ID..."
    aws iam delete-access-key --access-key-id "$ACCESS_KEY_ID" --user-name "$AWS_USER"
    log_action "Delete" "$ACCESS_KEY_ID" "Deleted"
    echo -e "\e[1;32mKey $ACCESS_KEY_ID has been deleted.\e[0m"
}

welcome_banner
prompt_for_username
menu
