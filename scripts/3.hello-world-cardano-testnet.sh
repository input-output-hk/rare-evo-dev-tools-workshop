#!/bin/bash

# This script automates the Aiken "Hello World" validator workflow.
# It assumes a local testnet is running and environment variables are set.
# It should be run from the root of your project directory.

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration ---
# ANSI Color Codes
BLUE='\033[1;34m'
GREEN='\033[1;32m'
PINK='\033[1;35m' # Pink/Magenta color
RED='\033[1;31m'  # Red for errors
NC='\033[0m' # No Color

# Define file paths and constants for clarity
TESTNET_MAGIC=42
DELEGATOR1_DIR="mytestnet/stake-delegators/delegator1"
DELEGATOR2_DIR="mytestnet/stake-delegators/delegator2"

HELLO_WORLD_SCRIPT_DIR="hello-world"
HELLO_WORLD_SCRIPT_FILE="$HELLO_WORLD_SCRIPT_DIR/hello-world.json"
HELLO_WORLD_ADDR_FILE="mytestnet/hello-world.addr"

DELEGATOR1_ADDR_FILE="$DELEGATOR1_DIR/payment.addr"
DELEGATOR1_SKEY_FILE="$DELEGATOR1_DIR/payment.skey"
DELEGATOR1_VKEY_FILE="$DELEGATOR1_DIR/payment.vkey"

DELEGATOR2_ADDR_FILE="$DELEGATOR2_DIR/payment.addr"
DELEGATOR2_SKEY_FILE="$DELEGATOR2_DIR/payment.skey"

LOCK_TX_RAW="mytestnet/lock-tx.raw"
LOCK_TX_SIGNED="mytestnet/lock-tx.signed"
UNLOCK_TX_RAW="mytestnet/unlock-tx.raw"
UNLOCK_TX_SIGNED="mytestnet/unlock-tx.signed"


# --- Helper Functions ---

# Function to print a formatted step header
print_step() {
  echo
  echo "======================================================================"
  echo "=> $1"
  echo "======================================================================"
  echo
}

# Function to wait for user input
press_to_continue() {
  echo
  # Use echo -e to interpret color codes and -n to prevent a newline
  echo -en "${BLUE}Press any key to continue to the next step...${NC}"
  read -n 1 -s -r
  # Add a newline after the user presses a key for clean formatting
  echo
}


# --- Script Start ---

print_step "Step 1: Build 'Hello World' script address"
COMMAND="cardano-cli conway address build \
  --payment-script-file $HELLO_WORLD_SCRIPT_FILE \
  --testnet-magic $TESTNET_MAGIC \
  --out-file $HELLO_WORLD_ADDR_FILE"
echo "$ $COMMAND"
eval "$COMMAND"
echo
echo -e "${GREEN}Script address created at: ${PINK}$HELLO_WORLD_ADDR_FILE${NC}"
echo -e "${GREEN}Address: ${PINK}$(cat $HELLO_WORLD_ADDR_FILE)${NC}"

press_to_continue
print_step "Step 2: Build address for delegator2"
COMMAND="cardano-cli conway address build \
  --payment-verification-key-file $DELEGATOR2_DIR/payment.vkey \
  --stake-verification-key-file $DELEGATOR2_DIR/staking.vkey \
  --testnet-magic $TESTNET_MAGIC \
  --out-file $DELEGATOR2_ADDR_FILE"
echo "$ $COMMAND"
eval "$COMMAND"
echo
echo -e "${GREEN}Address for delegator2 created at: ${PINK}$DELEGATOR2_ADDR_FILE${NC}"
echo -e "${GREEN}Address: ${PINK}$(cat $DELEGATOR2_ADDR_FILE)${NC}"

press_to_continue
print_step "Step 3: Find a UTxO in delegator2's wallet to lock funds"
COMMAND="cardano-cli conway query utxo --address $(< $DELEGATOR2_ADDR_FILE) --output-text"
echo "$ $COMMAND"
eval "$COMMAND"
# Programmatically find the UTxO with exactly 1000 ADA (1,000,000,000 lovelace)
UTXO_TO_LOCK=$(cardano-cli conway query utxo --address "$(< $DELEGATOR2_ADDR_FILE)" | jq -r 'keys[0]')

if [ -z "$UTXO_TO_LOCK" ]; then
  echo -e "${RED}Error: Could not find a UTxO in delegator2's wallet.${NC}"
  exit 1
fi

echo
echo -e "${GREEN}--> Found UTxO: ${PINK}$UTXO_TO_LOCK${NC}"


press_to_continue
print_step "Step 4: Build the datum"
COMMAND="cardano-cli address key-hash \
  --payment-verification-key-file $DELEGATOR1_VKEY_FILE | \
  sed 's/.*/\"&\"/' | \
  jq -c '{constructor: 0, fields: [{bytes: .}]}' > datum.json"
echo "$ $COMMAND"
eval "$COMMAND"
echo
echo -e "${GREEN}--> Created datum file: ${PINK}$(cat datum.json)${NC}"


press_to_continue
print_step "Step 5: Build the transaction to lock 900 ADA"
COMMAND="cardano-cli conway transaction build \
  --tx-in $UTXO_TO_LOCK \
  --tx-out $(< $HELLO_WORLD_ADDR_FILE)+900000000 \
  --tx-out-inline-datum-file datum.json \
  --change-address $(< $DELEGATOR2_ADDR_FILE) \
  --out-file $LOCK_TX_RAW"
echo "$ $COMMAND"
eval "$COMMAND"
echo
echo -e "${GREEN}--> Locking transaction created at: ${PINK}$LOCK_TX_RAW${NC}"


press_to_continue
print_step "Step 6: Sign the locking transaction"
COMMAND="cardano-cli conway transaction sign \
  --tx-file $LOCK_TX_RAW \
  --signing-key-file $DELEGATOR2_SKEY_FILE \
  --out-file $LOCK_TX_SIGNED"
echo "$ $COMMAND"
eval "$COMMAND"
echo
echo -e "${GREEN}--> Signed locking transaction created at: ${PINK}$LOCK_TX_SIGNED${NC}"


press_to_continue
print_step "Step 7: Submit the locking transaction"
COMMAND="cardano-cli conway transaction submit --tx-file $LOCK_TX_SIGNED"
echo "$ $COMMAND"
eval "$COMMAND"
echo
echo -e "${GREEN}--> Locking transaction submitted successfully!${NC}"


press_to_continue
print_step "Step 8: Verify funds are locked at the script address"
echo "(Waiting 5 seconds for the transaction to be processed...)"
sleep 5
COMMAND="cardano-cli conway query utxo --address $(< $HELLO_WORLD_ADDR_FILE)"
echo "$ $COMMAND"
eval "$COMMAND"


press_to_continue
print_step "Step 9: Build the transaction to UNLOCK funds from the script"
# Find the necessary inputs for the unlocking transaction
# The collateral should be a small UTxO, let's find the one with 5 ADA (5,000,000 lovelace).
COLLATERAL_UTXO=$(cardano-cli conway query utxo --address $(< $DELEGATOR1_ADDR_FILE) | jq -r 'to_entries[] | select(.value.value.lovelace == 5000000) | .key')

if [ -z "$COLLATERAL_UTXO" ]; then
  echo -e "${RED}Error: Could not find a UTxO with 5,000,000 lovelace to use as collateral.${NC}"
  exit 1
fi

# The script input is the UTxO currently locked at the script address.
SCRIPT_UTXO=$(cardano-cli conway query utxo --address $(< $HELLO_WORLD_ADDR_FILE) | jq -r 'keys[0]')

jq -c '{constructor:0,fields:[{bytes:.}]}' <<< "\"$(echo 'Hello, World!' | xxd -g1 | cut -d ' ' -f2-14  | tr -d ' ')\"" | tee redeemer.json

if [ -z "$SCRIPT_UTXO" ]; then
  echo -e "${RED}Error: Could not find a UTxO at the script address to unlock.${NC}"
  exit 1
fi

echo -e "${GREEN}--> Using Collateral UTxO: ${PINK}$COLLATERAL_UTXO${NC}"
echo -e "${GREEN}--> Using Script UTxO to unlock: ${PINK}$SCRIPT_UTXO${NC}"
echo -e "${GREEN}--> redeemer.json: ${PINK}$(cat redeemer.json)${NC}"
echo

COMMAND="cardano-cli conway transaction build \
  --tx-in-collateral $COLLATERAL_UTXO \
  --tx-in $SCRIPT_UTXO \
  --tx-in-script-file $HELLO_WORLD_SCRIPT_FILE \
  --tx-in-inline-datum-present \
  --tx-in-redeemer-file redeemer.json \
  --change-address $(< $DELEGATOR1_ADDR_FILE) \
  --required-signer $DELEGATOR1_SKEY_FILE \
  --out-file $UNLOCK_TX_RAW"
echo "$ $COMMAND"
eval "$COMMAND"
echo
echo -e "${GREEN}--> Unlocking transaction created at: ${PINK}$UNLOCK_TX_RAW${NC}"


press_to_continue
print_step "Step 10: Sign the unlocking transaction"
COMMAND="cardano-cli conway transaction sign \
  --tx-file $UNLOCK_TX_RAW \
  --signing-key-file $DELEGATOR1_SKEY_FILE \
  --out-file $UNLOCK_TX_SIGNED"
echo "$ $COMMAND"
eval "$COMMAND"
echo
echo -e "${GREEN}--> Signed unlocking transaction created at: ${PINK}$UNLOCK_TX_SIGNED${NC}"


press_to_continue
print_step "Step 11: Submit the unlocking transaction"
COMMAND="cardano-cli conway transaction submit --tx-file $UNLOCK_TX_SIGNED"
echo "$ $COMMAND"
eval "$COMMAND"
echo
echo -e "${GREEN}--> Unlocking transaction submitted successfully!${NC}"


press_to_continue
print_step "Step 12: Verify Final Balances"
echo -e "${GREEN}(Waiting 5 seconds for the network to update...)${NC}"
sleep 5

echo
echo -e "${GREEN}--- Final balance for Script Address (should be empty) ---${NC}"
COMMAND="cardano-cli conway query utxo --address $(< $HELLO_WORLD_ADDR_FILE) --output-text"
echo "$ $COMMAND"
eval "$COMMAND"

echo
echo -e "${GREEN}--- Final balance for Delegator1 Address ---${NC}"
COMMAND="cardano-cli conway query utxo --address $(< $DELEGATOR1_ADDR_FILE) --output-text"
echo "$ $COMMAND"
eval "$COMMAND"

echo
echo -e "${GREEN}--- Final balance for Delegator2 Address ---${NC}"
COMMAND="cardano-cli conway query utxo --address $(< $DELEGATOR2_ADDR_FILE) --output-text"
echo "$ $COMMAND"
eval "$COMMAND"


print_step "Workflow complete!"
