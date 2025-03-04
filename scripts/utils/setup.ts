import { SuiObjectChangePublished } from "@mysten/sui/client";
import { Transaction } from "@mysten/sui/transactions";
import getExecStuff from "./execStuff";
import { execSync } from "child_process";
import { promises as fs } from "fs";

const getPackageId = async () => {
    let packageId = "";
    let publisher = "";
    let CoinMetadataCity = "";
    let CoinMetdataVillage = "";
    let CoinCityRegistry = ""; 
    let CoinVillageRegistry = "";
    let UpgradeCap = "";

    try {
        const { keypair, client } = getExecStuff();
        const packagePath = process.cwd();
        const { modules, dependencies } = JSON.parse(
            execSync(
                `sui move build --dump-bytecode-as-base64 --path ${packagePath}`,
                {
                    encoding: "utf-8",
                }
            )
        );

        const tx = new Transaction();
        const [upgradeCap] = tx.publish({
            modules,
            dependencies,
        });
        tx.transferObjects([upgradeCap], keypair.getPublicKey().toSuiAddress());

        const result = await client.signAndExecuteTransaction({
            signer: keypair,
            transaction: tx,
            options: {
                showEffects: true,
                showObjectChanges: true,
            },
            requestType: "WaitForLocalExecution"
        });
        console.log(result.digest);
        const digest_ = result.digest;
        if (result.effects?.status?.status !== "success") {
			console.log("\n\nPublishing failed");
            return;
        }

        packageId = ((result.objectChanges?.filter(
            (a) => a.type === "published"
        ) as SuiObjectChangePublished[]) ?? [])[0].packageId.replace(
            /^(0x)(0+)/,
            "0x"
        ) as string;

        //await sleep(1000);

        if (!digest_) {
            console.log("Digest is not available");
            return { packageId };
        }
        
        const txn = await client.waitForTransaction({
            digest: result.digest,
            options: {
                showEffects: true,
                showInput: false,
                showEvents: false,
                showObjectChanges: true,
                showBalanceChanges: false,
            },
        });

        for (const item of txn.objectChanges || []) {
            if (item.type === "created") {
                if (item.objectType === `0x2::package::Publisher`)
                    publisher = String(item.objectId);
                if (item.objectType === `0x2::coin::CoinMetadata<${packageId}::city::CITY>`)
                    CoinMetadataCity = String(item.objectId);
                if (item.objectType === `0x2::coin::CoinMetadata<${packageId}::village::VILLAGE>`)
                    CoinMetdataVillage = String(item.objectId);
                if (item.objectType === `${packageId}::city::CoinCityRegistry`)
                    CoinCityRegistry = String(item.objectId);
                if (item.objectType === `${packageId}::village::CoinVillageRegistry`)
                    CoinVillageRegistry = String(item.objectId);
                if (item.objectType === `0x2::package::UpgradeCap`)
                    UpgradeCap = String(item.objectId);
                
            }
        }
        const content = `export const packageId = '${packageId}';
export const publisher = '${publisher}';
export const CoinMetadataCity = '${CoinMetadataCity}'; 
export const CoinMetadataVillage = '${CoinMetdataVillage}';
export const UpgradeCap = '${UpgradeCap}';
export const COIN_A_TYPE = '';
export const COIN_B_TYPE = '';
export const CoinCityRegistry = '${CoinCityRegistry}';
export const CoinVillageRegistry = '${CoinVillageRegistry}';
export const GlobalConfig = '0x9774e359588ead122af1c7e7f64e14ade261cfeecdb5d0eb4a5b3b4c8ab8bd3e';
export const Pools = '0x50eb61dd5928cec5ea04711a2e9b72e5237e79e9fbcd2ce3d5469dc8708e0ee2';
export const ReceiptTokenTreasuryCap = '';\n`;

        await fs.writeFile(`${packagePath}/scripts/utils/packageInfo.ts`, content);

        return {
            packageId,
            publisher, 
            CoinMetadataCity,
            CoinMetdataVillage,
            CoinCityRegistry,
            CoinVillageRegistry,
            UpgradeCap,
        };
} 
    catch (error) {
        console.error(error);
    }
};
// Call the async function and handle the result
getPackageId()
    .then((result) => {
        console.log(result);
    })
    .catch((error) => {
        console.error(error);
    });

export default getPackageId;
