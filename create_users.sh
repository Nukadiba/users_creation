#!/bin/bash

# Ensure the script is run as root
[ "$EUID" -ne 0 ] && echo "Please run as root" && exit 1

# Check if the filename is provided as an argument
[ -z "$1" ] && echo "Usage: $0 <name-of-text-file>" && exit 1

INPUT_FILE="$1"
LOG_FILE="/var/log/user_management.log"
PASSWORD_FILE="/var/secure/user_passwords.csv"

# Ensure /var/secure directory exists and set appropriate permissions
mkdir -p /var/secure
chmod 700 /var/secure
touch "$LOG_FILE" "$PASSWORD_FILE"
chmod 600 "$PASSWORD_FILE"

log_message() {
  echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

generate_password() {
  tr -dc 'A-Za-z0-9@#$%&*' < /dev/urandom | head -c 12
}

while IFS=";" read -r username groups; do
  username=$(echo "$username" | xargs)
  groups=$(echo "$groups" | xargs)
  
  [ -z "$username" ] && log_message "Skipping empty username" && continue
  id "$username" &>/dev/null && log_message "User $username already exists" && continue
  
  groupadd "$username" && log_message "Group $username created"
  useradd -m -g "$username" -s /bin/bash "$username" && log_message "User $username created with home directory"

  IFS="," read -ra ADDR <<< "$groups"
  for group in "${ADDR[@]}"; do
    group=$(echo "$group" | xargs)
    [ -z "$group" ] && continue
    getent group "$group" >/dev/null || groupadd "$group" && log_message "Group $group created"
    usermod -aG "$group" "$username" && log_message "User $username added to group $group"
  done

  password=$(generate_password)
  echo "$username:$password" | chpasswd && log_message "Password set for user $username"
  echo "$username,$password" >> "$PASSWORD_FILE"
  chmod 700 "/home/$username" && chown "$username:$username" "/home/$username"
  log_message "Permissions set for user $username's home directory"
done < "$INPUT_FILE"

echo "User creation process completed. Check $LOG_FILE for details."
exit 0
