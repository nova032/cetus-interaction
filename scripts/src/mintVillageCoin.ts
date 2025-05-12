
import { Transaction } from '@mysten/sui/transactions';
import getExecStuff from '../utils/execStuff';
import { CoinVillageRegistry, packageId,} from '../utils/packageInfo';

async function mintVillageCoin() {

    console.log("================ Minting Village Coin ================");
    
    const { keypair, client } = getExecStuff();
    const tx = new Transaction();

    let coin = tx.moveCall({
        target: `0xebabbe4747d4c6a2203075d106b8a18bb534f587ee1ea0ed7ea1e0c857be7112::village::mint`,
        arguments: [
            tx.object('0x91ade1a90c35e89e777315260d53c349118b02027b5cd1e1b122635083a06594'), 
            tx.pure.u64(100_000_000_000_000),
        ],
        typeArguments: [
            '0xebabbe4747d4c6a2203075d106b8a18bb534f587ee1ea0ed7ea1e0c857be7112::village::VILLAGE'
        ]
    });

    tx.transferObjects([coin], '0xb83450b323da120dc7772f3ef7b6d1bc15d2d8486bcd1a772242e94c8a73721b');
    
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
mintVillageCoin().catch(error => {
    console.error("Error in minting City Coin", error);
});