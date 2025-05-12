
import { coinWithBalance, Transaction } from '@mysten/sui/transactions';
import getExecStuff from '../utils/execStuff';
import {  GlobalConfig, packageId,} from '../utils/packageInfo';

async function swapB2A() {

    console.log("================ Swap B2A ================");
    
    const { keypair, client } = getExecStuff();
    const tx = new Transaction();

    const depositCoin = coinWithBalance({
      type: `${packageId}::city::CITY`, // Deposit Coin Type
      balance: 50_000_000_000, // you can put amount to deposit
    });

    let coin = tx.moveCall({
        target: `${packageId}::v_swap::swap_b2a`,
        arguments: [
            tx.object(GlobalConfig), 
            tx.object('0xf9ae1984df2295e9a9ba2b18cc6eac88e2b94b3c8d264c152ef39450da67cea4'),
            tx.object('0x1f5fa5c820f40d43fc47815ad06d95e40a1942ff72a732a92e8ef4aa8cde70a5'),
            depositCoin,
            tx.object.clock(),
        ],
        typeArguments:[
            `${packageId}::village::VILLAGE`,
            `${packageId}::city::CITY`
        ]
    });

    tx.transferObjects([coin], keypair.getPublicKey().toSuiAddress());
    const result = await client.signAndExecuteTransaction({
        signer: keypair,
        transaction: tx,
        requestType: "WaitForLocalExecution",
        options: {
            showObjectChanges: true,
            showEffects: true,
            showRawInput: true,
        },
    });
 
    console.log(result.digest); 

}

// Call the async function to execute
swapB2A().catch(error => {
    console.error("Error in minting City Coin", error);
});