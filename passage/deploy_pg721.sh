#!/bin/bash
CHAINID="passage-1"
KEY="mykey"
PATH_TO_CONTRACTS="/home/vitwit/passage/passage-contracts"

ADDR=$(passage keys show $KEY -a)

# Update the value in the .env file
sed -i "s/^minter_addr=.*/minter_addr=$ADDR/" .env

echo "Deploying contract..."
passage tx wasm store "$PATH_TO_CONTRACTS"/artifacts/pg721_metadata_onchain.wasm --from $KEY --gas auto --gas-adjustment 1.15 --chain-id $CHAINID -y -b block



NFT_CODE_ID=$(passage query wasm list-code --output json | jq -r '.code_infos[-1].code_id')
sed -i "s/^new_nft_code_id=.*/new_nft_code_id=$NFT_CODE_ID/" .env

# Load INIT payload
NFT_INIT='{
  "name": "MetaHuahua",
  "symbol": "MH",
  "minter": "'$ADDR'",
  "collection_info": {
    "creator": "pasg166a65em64adkm8mt8j2wcz7hzlq52x9qvm06ev",
    "description": "THE WOOFIEST PASSPORT TO THE METAVERSE",
    "image": "ipfs://bafybeideczllcb5kz75hgy25irzevarybvazgdiaeiv2xmgqevqgo6d3ua/2990.png",
    "external_link": "https://www.aaa-metahuahua.com/",
    "royalty_info": {
      "payment_address": "pasg166a65em64adkm8mt8j2wcz7hzlq52x9qvm06ev",
      "share": "0.1"
    }
  }
}'

# instantiate contract
echo "Instantiating contract..."
passage tx wasm instantiate "$NFT_CODE_ID" "$NFT_INIT" --from $KEY --chain-id $CHAINID --label "nft metadata onchain" --no-admin --gas auto --gas-adjustment 1.15 -y -b block



NFT_CONTRACT=$(passage query wasm list-contract-by-code "$NFT_CODE_ID" --output json | jq -r '.contracts[-1]')
sed -i "s/^new_nft_address=.*/new_nft_address=$NFT_CONTRACT/" .env

echo "NFT contract deployed. NFT contract address: $NFT_CONTRACT"
len=$(jq '.migrations | length' ../output/nft_migrations.json)
batch_size=50
iterations=$(((len + batch_size -1) / batch_size))

# migrations
for ((i=0;i<iterations;i++)); do 
    start_index=$((i*batch_size))
    end_index=$((start_index+batch_size))
    TOKENS=$(jq ".migrations[$start_index:$end_index]" ../output/nft_migrations.json)
    MIGRATIONS='{
        "migrate": {
            "migrations": '$TOKENS'
        }    
    }'

    echo "Migration $((i+1)) / $iterations"
    passage tx wasm execute "$NFT_CONTRACT" "$MIGRATIONS" --amount 100stake --from $KEY --chain-id $CHAINID --gas auto --gas-adjustment 1.15 -y -b block

    
done
# mark migration done

echo "Migration done"
passage tx wasm execute "$NFT_CONTRACT" '{"migration_done":{}}' --amount 100stake --from $KEY --chain-id $CHAINID --gas auto --gas-adjustment 1.15 -y -b block