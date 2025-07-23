#!/bin/bash

# This script automates the Cardano transaction workflow described in the tutorial.
# It assumes that a local testnet has been started using the instructions
# and that environment variables like CARDANO_NODE_SOCKET_PATH are set.

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration ---
# ANSI Color Codes
BLUE='\033[1;34m'
GREEN='\033[1;32m'
PINK='\033[1;35m' # Pink/Magenta color
NC='\033[0m' # No Color

# Define file paths and constants for clarity
TESTNET_MAGIC=42
DELEGATOR1_DIR="mytestnet/stake-delegators/delegator1"
UTXO1_DIR="mytestnet/utxo-keys/utxo1"
DELEGATOR1_ADDR_FILE="$DELEGATOR1_DIR/payment.addr"
UTXO1_ADDR_FILE="$UTXO1_DIR/utxo.addr"
TX_RAW_FILE="mytestnet/tx.raw"
TX_SIGNED_FILE="mytestnet/tx.signed"


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
  echo
  # Use echo -e to interpret color codes and -n to prevent a newline
  echo -en "${BLUE}Press any key to continue to the next step...${NC}"
  read -n 1 -s -r
  # Add a newline after the user presses a key for clean formatting
  echo
}


# --- Script Start ---

print_step "Step 1: Build address for delegator1"
COMMAND="cardano-cli conway address build \
  --payment-verification-key-file $DELEGATOR1_DIR/payment.vkey \
  --stake-verification-key-file $DELEGATOR1_DIR/staking.vkey \
  --testnet-magic $TESTNET_MAGIC \
  --out-file $DELEGATOR1_ADDR_FILE"
echo "$ $COMMAND"
eval "$COMMAND"
echo
echo -e "${GREEN}Address for delegator1 created at: ${PINK}$DELEGATOR1_ADDR_FILE${NC}"
echo -e "${GREEN}Address: ${PINK}$(cat $DELEGATOR1_ADDR_FILE)${NC}"
press_to_continue


print_step "Step 2: Query initial balance for delegator1"
COMMAND="cardano-cli conway query utxo --address $(< $DELEGATOR1_ADDR_FILE) --output-text"
echo "$ $COMMAND"
eval "$COMMAND"
press_to_continue


print_step "Step 3: Find the input UTxO from utxo1"
COMMAND="cardano-cli conway query utxo --address $(< $UTXO1_ADDR_FILE) --output-text"
echo "$ $COMMAND"
eval "$COMMAND"
# Programmatically extract the first UTXO to use as an input
UTXO_IN=$(cardano-cli conway query utxo --address "$(< $UTXO1_ADDR_FILE)" | jq -r 'keys[0]')
echo
echo -e "${GREEN}--> UTxO to be spent: ${PINK}$UTXO_IN${NC}"
press_to_continue


print_step "Step 4: Build the transaction (tx.raw)"
COMMAND="cardano-cli conway transaction build \
  --tx-in $UTXO_IN \
  --tx-out $(< $DELEGATOR1_ADDR_FILE)+1000000000 \
  --tx-out $(< $DELEGATOR1_ADDR_FILE)+5000000 \
  --change-address $(< $UTXO1_ADDR_FILE) \
  --out-file $TX_RAW_FILE"
echo "$ $COMMAND"
eval "$COMMAND"
echo
echo -e "${GREEN}--> Raw transaction created at: ${PINK}$TX_RAW_FILE${NC}"
press_to_continue


print_step "Step 5: Inspect the raw, unsigned transaction"
COMMAND="cardano-cli debug transaction view --tx-file $TX_RAW_FILE"
echo "$ $COMMAND"
eval "$COMMAND"
press_to_continue


print_step "Step 6: Attempt to submit the UNSIGNED transaction (this will fail)"
COMMAND="cardano-cli conway transaction submit --tx-file $TX_RAW_FILE"
echo "$ $COMMAND"
# Temporarily disable 'exit on error' because this command is expected to fail
set +e
eval "$COMMAND"
# Re-enable 'exit on error'
set -e
echo
echo -e "${GREEN}--> As expected, submission failed due to missing witnesses.${NC}"
press_to_continue


print_step "Step 7: Sign the transaction"
COMMAND="cardano-cli conway transaction sign \
  --tx-file $TX_RAW_FILE \
  --signing-key-file $UTXO1_DIR/utxo.skey \
  --out-file $TX_SIGNED_FILE"
echo "$ $COMMAND"
eval "$COMMAND"
echo
echo -e "${GREEN}--> Signed transaction created at: ${PINK}$TX_SIGNED_FILE${NC}"
press_to_continue


print_step "Step 8: Submit the SIGNED transaction"
COMMAND="cardano-cli conway transaction submit --tx-file $TX_SIGNED_FILE"
echo "$ $COMMAND"
eval "$COMMAND"
echo
echo -e "${GREEN}--> Transaction submitted successfully!${NC}"
press_to_continue


print_step "Step 9: Query Final Balances"
sleep 3
echo
echo "--- Final balance for utxo1 (change address) ---"
COMMAND="cardano-cli conway query utxo --address $(< $UTXO1_ADDR_FILE) --output-text"
echo "$ $COMMAND"
eval "$COMMAND"

echo 
echo "--- Final balance for delegator1 ---"
COMMAND="cardano-cli conway query utxo --address $(< $DELEGATOR1_ADDR_FILE) --output-text"
echo "$ $COMMAND"
eval "$COMMAND"

print_step "Workflow complete!"
