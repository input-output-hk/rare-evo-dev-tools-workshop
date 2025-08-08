#!/bin/bash

# This script programmatically modifies the conway, shelley, and alonzo
# genesis files with a series of predefined updates, placing the
# output in the 'env/' directory.
#
# It requires 'jq', a command-line JSON processor.

# --- Main function to orchestrate the updates ---
main() {
    echo "🚀 Starting genesis file update process..."
    echo ""

    # Check for jq dependency first
    if ! command -v jq &> /dev/null; then
        echo "❌ Error: 'jq' is not installed. Please install it to run this script."
        echo "   On Debian/Ubuntu: sudo apt-get install jq"
        echo "   On macOS (Homebrew): brew install jq"
        exit 1
    fi

    # Ensure the target directory exists
    echo "Ensuring 'env/' directory exists..."
    mkdir -p env

    echo ""

    update_conway_genesis
    echo "----------------------------------------"
    update_shelley_genesis
    echo "----------------------------------------"
    update_alonzo_genesis

    echo ""
    echo "✅ All genesis files have been updated successfully in the 'env/' directory!"
}

# --- Function to update conway-genesis.json ---
update_conway_genesis() {
    local FILE_PATH="mytestnet/conway-genesis.json"
    echo "Updating '$FILE_PATH'..."

    if [ ! -f "$FILE_PATH" ]; then
        echo "⚠️  Warning: '$FILE_PATH' not found. Skipping."
        return
    fi

    # Define the JSON data for conway-genesis.json
    local MEMBERS_JSON='{
      "keyHash-697b5276599bd0adc12e2b3d96b132458458a78bebf152068199cd71": 10,
      "keyHash-3b5f7afd64d9cfbd221318c34ccff886784875559c50dbaec36ceae6": 10,
      "keyHash-eae8739fc1834101e93cf8061fa23e4a87aea13f8104831cc0df7b4c": 10
    }'
    local THRESHOLD_JSON='{ "numerator": 2, "denominator": 3 }'
    local DREP_THRESHOLDS_JSON='{
      "committeeNoConfidence": 0.5, "committeeNormal": 0.5, "hardForkInitiation": 0.5,
      "motionNoConfidence": 0.5, "ppEconomicGroup": 0.5, "ppGovGroup": 0.5,
      "ppNetworkGroup": 0.5, "ppTechnicalGroup": 0.5, "treasuryWithdrawal": 0.5,
      "updateToConstitution": 0.5
    }'

    local TEMP_FILE
    TEMP_FILE=$(mktemp)

    # Use jq to apply all modifications
    jq --argjson members "$MEMBERS_JSON" \
       --argjson threshold "$THRESHOLD_JSON" \
       --argjson dRepThresholds "$DREP_THRESHOLDS_JSON" \
       '.committee.members = $members | .committee.threshold = $threshold | .govActionLifetime = 6 | .dRepVotingThresholds = $dRepThresholds | .minFeeRefScriptCostPerByte = 15 | .dRepDeposit = 500000000 | .govActionDeposit = 100000000000' \
       "$FILE_PATH" > "$TEMP_FILE"

    if [ $? -ne 0 ]; then
        echo "❌ Error: jq command failed for $FILE_PATH. File not changed."
        rm "$TEMP_FILE"
        return 1
    fi

    mv "$TEMP_FILE" "$FILE_PATH"
    echo "👍 Success: '$FILE_PATH' was updated."
}

# --- Function to update shelley-genesis.json ---
update_shelley_genesis() {
    local FILE_PATH="mytestnet/shelley-genesis.json"
    echo "Updating '$FILE_PATH'..."

    if [ ! -f "$FILE_PATH" ]; then
        echo "⚠️  Warning: '$FILE_PATH' not found. Skipping."
        return
    fi

    # Define the new protocolParams object with the updated keyDeposit
    local PROTOCOL_PARAMS_JSON='{
      "a0": 0.3, "decentralisationParam": 1, "eMax": 18,
      "extraEntropy": { "tag": "NeutralNonce" },
      "keyDeposit": 2000000, "maxBlockBodySize": 90112, "maxBlockHeaderSize": 1100,
      "maxTxSize": 16384, "minFeeA": 44, "minFeeB": 155381,
      "minPoolCost": 170000000, "minUTxOValue": 1000000, "nOpt": 100,
      "poolDeposit": 500000000,
      "protocolVersion": { "major": 10, "minor": 0 },
      "rho": 0.003, "tau": 0.2
    }'

    local TEMP_FILE
    TEMP_FILE=$(mktemp)

    # Use jq to replace the protocolParams object
    jq --argjson params "$PROTOCOL_PARAMS_JSON" '.protocolParams = $params' "$FILE_PATH" > "$TEMP_FILE"

    if [ $? -ne 0 ]; then
        echo "❌ Error: jq command failed for $FILE_PATH. File not changed."
        rm "$TEMP_FILE"
        return 1
    fi

    mv "$TEMP_FILE" "$FILE_PATH"
    echo "👍 Success: '$FILE_PATH' was updated."
}

# --- Function to update alonzo-genesis.json ---
update_alonzo_genesis() {
    local FILE_PATH="mytestnet/alonzo-genesis.json"
    echo "Updating '$FILE_PATH'..."

    if [ ! -f "$FILE_PATH" ]; then
        echo "⚠️  Warning: '$FILE_PATH' not found. Skipping."
        return
    fi

    # Define the entire new costModels object
    local COST_MODELS_JSON='{
      "PlutusV1": [ 100788, 420, 1, 1, 1000, 173, 0, 1, 1000, 59957, 4, 1, 11183, 32, 201305, 8356, 4, 16000, 100, 16000, 100, 16000, 100, 16000, 100, 16000, 100, 16000, 100, 100, 100, 16000, 100, 94375, 32, 132994, 32, 61462, 4, 72010, 178, 0, 1, 22151, 32, 91189, 769, 4, 2, 85848, 228465, 122, 0, 1, 1, 1000, 42921, 4, 2, 24548, 29498, 38, 1, 898148, 27279, 1, 51775, 558, 1, 39184, 1000, 60594, 1, 141895, 32, 83150, 32, 15299, 32, 76049, 1, 13169, 4, 22100, 10, 28999, 74, 1, 28999, 74, 1, 43285, 552, 1, 44749, 541, 1, 33852, 32, 68246, 32, 72362, 32, 7243, 32, 7391, 32, 11546, 32, 85848, 228465, 122, 0, 1, 1, 90434, 519, 0, 1, 74433, 32, 85848, 228465, 122, 0, 1, 1, 85848, 228465, 122, 0, 1, 1, 270652, 22588, 4, 1457325, 64566, 4, 20467, 1, 4, 0, 141992, 32, 100788, 420, 1, 1, 81663, 32, 59498, 32, 20142, 32, 24588, 32, 20744, 32, 25933, 32, 24623, 32, 53384111, 14333, 10 ],
      "PlutusV2": [ 100788, 420, 1, 1, 1000, 173, 0, 1, 1000, 59957, 4, 1, 11183, 32, 201305, 8356, 4, 16000, 100, 16000, 100, 16000, 100, 16000, 100, 16000, 100, 16000, 100, 100, 100, 16000, 100, 94375, 32, 132994, 32, 61462, 4, 72010, 178, 0, 1, 22151, 32, 91189, 769, 4, 2, 85848, 228465, 122, 0, 1, 1, 1000, 42921, 4, 2, 24548, 29498, 38, 1, 898148, 27279, 1, 51775, 558, 1, 39184, 1000, 60594, 1, 141895, 32, 83150, 32, 15299, 32, 76049, 1, 13169, 4, 22100, 10, 28999, 74, 1, 28999, 74, 1, 43285, 552, 1, 44749, 541, 1, 33852, 32, 68246, 32, 72362, 32, 7243, 32, 7391, 32, 11546, 32, 85848, 228465, 122, 0, 1, 1, 90434, 519, 0, 1, 74433, 32, 85848, 228465, 122, 0, 1, 1, 85848, 228465, 122, 0, 1, 1, 955506, 213312, 0, 2, 270652, 22588, 4, 1457325, 64566, 4, 20467, 1, 4, 0, 141992, 32, 100788, 420, 1, 1, 81663, 32, 59498, 32, 20142, 32, 24588, 32, 20744, 32, 25933, 32, 24623, 32, 43053543, 10, 53384111, 14333, 10, 43574283, 26308, 10 ]
    }'

    local TEMP_FILE
    TEMP_FILE=$(mktemp)

    # Use jq to replace the entire costModels object
    jq --argjson models "$COST_MODELS_JSON" '.costModels = $models' "$FILE_PATH" > "$TEMP_FILE"

    if [ $? -ne 0 ]; then
        echo "❌ Error: jq command failed for $FILE_PATH. File not changed."
        rm "$TEMP_FILE"
        return 1
    fi

    mv "$TEMP_FILE" "$FILE_PATH"
    echo "👍 Success: '$FILE_PATH' was updated."
}


# --- Execute the main function ---
main