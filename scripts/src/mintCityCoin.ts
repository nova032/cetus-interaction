
import { Transaction } from '@mysten/sui/transactions';
import getExecStuff from '../utils/execStuff';
import { CoinCityRegistry, packageId,} from '../utils/packageInfo';

async function mintCityCoin() {

    console.log("================ Minting City Coin ================");
    
    const { keypair, client } = getExecStuff();
    const tx = new Transaction();

    let coin = tx.moveCall({
        target: `${packageId}::city::mint`,
        arguments: [
            tx.object(CoinCityRegistry), 
            tx.pure.u64(50_000_000_000),
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
mintCityCoin().catch(error => {
    console.error("Error in minting City Coin", error);
});