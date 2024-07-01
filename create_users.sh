#!/bin/bash

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# Check if the filename is provided as an argument
if [ -z "$1" ]; then
  echo "Usage: $0 <name-of-text-file>"
  exit 1
fi

# Input file containing usernames and groups
INPUT_FILE="$1"

# Log file
LOG_FILE="/var/log/user_management.log"
# Password file
PASSWORD_FILE="/var/secure/user_passwords.csv"

# Ensure /var/secure directory exists and set appropriate permissions
mkdir -p /var/secure
chmod 700 /var/secure

# Ensure the log file and password file are created and set appropriate permissions
touch "$LOG_FILE"
touch "$PASSWORD_FILE"
chmod 600 "$PASSWORD_FILE"

# Function to log messages
log_message() {
  echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Function to generate random passwords
generate_password() {
  tr -dc 'A-Za-z0-9@#$%&*' < /dev/urandom | head -c 12
}

# Read the input file line by line
while IFS=";" read -r username groups; do
  # Remove any leading/trailing whitespace
  username=$(echo "$username" | xargs)
  groups=$(echo "$groups" | xargs)
  
  # Skip empty usernames
  if [ -z "$username" ]; then
    log_message "Skipping empty username"
    continue
  fi

  # Check if the user already exists
  if id "$username" &>/dev/null; then
    log_message "User $username already exists"
    continue
  fi
  
  # Create a personal group for the user
  groupadd "$username"
  log_message "Group $username created"

  # Create the user with the personal group
  useradd -m -g "$username" -s /bin/bash "$username"
  log_message "User $username created with home directory"

  # Set up additional groups
  if [ -n "$groups" ]; then
    IFS="," read -ra ADDR <<< "$groups"
    for group in "${ADDR[@]}"; do
      group=$(echo "$group" | xargs)  # Remove any leading/trailing whitespace
      if [ -n "$group" ]; then  # Skip empty group names
        if ! getent group "$group" >/dev/null; then
          groupadd "$group"
          log_message "Group $group created"
        fi
        usermod -aG "$group" "$username"
        log_message "User $username added to group $group"
      fi
    done
  fi

  # Generate a random password for the user
  password=$(generate_password)
  echo "$username:$password" | chpasswd
  log_message "Password set for user $username"

  # Store the username and password in the password file
  echo "$username,$password" >> "$PASSWORD_FILE"
  
  # Set appropriate permissions for the user's home directory
  chmod 700 "/home/$username"
  chown "$username:$username" "/home/$username"
  log_message "Permissions set for user $username's home directory"

done < "$INPUT_FILE"

echo "User creation process completed. Check $LOG_FILE for details."

exit 0
