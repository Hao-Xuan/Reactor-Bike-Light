//define version number and read/write paths and filenames
const readFilename = "../Node Dev/reactor_Main.eeprom";
const writeFilename = "../App Dev/firmware/FirmwareRevision.js";
//calculate crcLookupTable codes
const crcPolynomial = 0x15935;
let crcLookupTable = [];
for (let divident = 0; divident < 256; divident++) {
    let currentByte = divident << 8;
    for (let bit = 0; bit < 8; bit++) {
        if ((currentByte & 0x8000) !== 0) {
            currentByte = ((currentByte << 1) & 0xFFFF) ^ (crcPolynomial & 0xFFFF);
        } else {
            currentByte = (currentByte << 1) & 0xFFFF;
        }
    }
    crcLookupTable.push(currentByte);
}
//extract hexArray from binary EEPROM file
const fs = require('fs');
const buffer = fs.readFileSync(readFilename);
const hexArray = [...buffer];
//find version number
let version;
for (let idx = 0; idx < 512; idx++) {
    const checkArray = hexArray.slice(idx, idx + 8);
    const checkVersion = String.fromCharCode.apply(null, checkArray);
    if (checkVersion === 'VERSION ') {
        const versionArray = hexArray.slice(idx + 8, idx + 16);
        version = String.fromCharCode.apply(null, versionArray);
        break;
    }
}
//calculate crcArray elements
let crc;
let crcArray = [];
for (let idx = 0; idx < 2048; idx++) {
    const address = 16 * idx;
    const addressLow = address % 256;
    const addressHigh = (address - addressLow) / 256;
    const addressArray = [addressHigh, addressLow];
    const dataArray = hexArray.slice(address, address + 16);
    const byteArray = addressArray.concat(dataArray);
    crc = 0;
    byteArray.forEach(
        (byte) => {
            const crcLookupIndex = ((crc >> 8) & 0xFF) ^ byte;
            crc = ((crc << 8) & 0xFFFF) ^ crcLookupTable[crcLookupIndex];
        }
    );
    crcArray.push(crc);
}
//construct string to write to file
//inject object declaration, version, and crcPolynomial values
let writeData = "const FirmwareRevision = {"
    + "\n\tversion: "
    + JSON.stringify(version)
    + ",\n\tcrcPolynomial: "
    + `${crcPolynomial}`
    + ",\n\tcrcLookupTable: [";
//inject crcLookupTable rows
for (let idx = 0; idx < 16; idx++) {
    const lookupRow = crcLookupTable.slice(16 * idx, 16 * (idx + 1));
    writeData += `\n\t\t${lookupRow}`;
    if (idx < 15) {
        writeData += ",";
    }
}
//inject crcArray rows
writeData += "\n\t],\n\tcrcArray: [";
for (let idx = 0; idx < 128; idx++) {
    const crcRow = crcArray.slice(16 * idx, 16 * (idx + 1));
    writeData += `\n\t\t${crcRow}`;
    if (idx < 127) {
        writeData += ",";
    }
}
//inject hexArray rows
writeData += "\n\t],\n\thexArray: [";
for (let idx = 0; idx < 2048; idx++) {
    const hexRow = hexArray.slice(16 * idx, 16 * (idx + 1));
    writeData += `\n\t\t${hexRow}`;
    if (idx < 2047) {
        writeData += ",";
    }
}
//add export declaration
writeData += "\n\t]\n};\n\nexport default FirmwareRevision;";
//write string to file and log summary
fs.writeFile(writeFilename, writeData, (err) => {
    if (err) {
        throw err;
    } else {
        console.log("ProcessReactorBinary - crcLookupTable length:", crcLookupTable.length);
        console.log("ProcessReactorBinary - crcArray length:", crcArray.length);
        console.log("ProcessReactorBinary - hexArray length:", hexArray.length);
        console.log("ProcessReactorBinary - File saved:", writeFilename, `v${version}`);
    }
});