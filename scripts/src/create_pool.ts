import { Transaction } from '@mysten/sui/transactions';
import * as dotenv from 'dotenv';
import getExecStuff from '../utils/execStuff';
import { CoinCityRegistry, CoinMetadataCity, CoinMetadataVillage, CoinVillageRegistry, GlobalConfig, packageId, Pools,} from '../utils/packageInfo';
dotenv.config();

async function depositFor() {
    const { keypair, client } = getExecStuff();
    const tx = new Transaction();


    tx.moveCall({
        target: `${packageId}::v_swap::create_cetus_pool_v_s`,
        arguments: [
            tx.object(GlobalConfig),
            tx.object(Pools),
            tx.object(CoinCityRegistry),
            tx.object(CoinVillageRegistry),
            tx.object(CoinMetadataCity),
            tx.object(CoinMetadataVillage),
            tx.object.clock()
        ], 
    });
    const result = await client.signAndExecuteTransaction({
        signer: keypair,
        transaction: tx,
        requestType: "WaitForLocalExecution",
        options: {
            showObjectChanges: true,
            showEffects: true,
        },
    });
    console.log(result.digest);
    
}
depositFor();