import { BleManager, fullUUID } from "react-native-ble-plx";
import { Buffer } from 'buffer';

export default class ReactorBLE {
    constructor() {
        this.isScanning = false;
        this.isConnecting = false;
        this.isConnected = false;
        this.readServiceUUIDs = [];
        this.readCharacteristicUUIDs = [];
        this.writeWithResponseServiceUUIDs = [];
        this.writeWithResponseCharacteristicUUIDs = [];
        this.writeWithoutResponseServiceUUIDs = [];
        this.writeWithoutResponseCharacteristicUUIDs = [];
        this.notifyServiceUUIDs = [];
        this.notifyCharacteristicUUIDs = [];
        this.manager = new BleManager();
    }

    destroy() {
        this.manager.destroy();
    }

    getState() {
        return new Promise((resolve, reject) => {
            this.manager.state()
                .then((state) => {
                    //console.log("BleUtilities - ble manager state:",state);
                    resolve(state);
                })
                .catch(err => {
                    //console.log("BleUtilities - ble state error:", err);
                    reject(err);
                });
        });
    }

    enableBle() {
        return new Promise((resolve,reject) => {
            this.manager.enable()
            .then(() => {
                //console.log("BleUtilities - ble enabled...");
                resolve();
            })
            .catch(err => {
                //console.log("BleUtilities - ble enable error:",err);
                reject(err);
            });
        });
    }

    connectionCheck(id) {
        return new Promise((resolve, reject) => {
            this.manager.isDeviceConnected(id)
                .then(state => {
                    this.isConnected = state;
                    //console.log("BleUtilities - connection state:",state);
                    resolve(state);
                })
                .catch(err => {
                    reject(err);
                });
        });
    }

    scanForReactors() {
        return new Promise((resolve, reject) => {
            this.isScanning = true;
            this.manager.startDeviceScan(
                null,
                { allowDuplicates: false },
                (error, device) => {
                    if (error) {
                        reject(error);
                    } else {
                        if (device.name === "Leviathan Reactor") {
                            this.manager.stopDeviceScan();
                            this.isScanning = false;
                            resolve(device.id);
                        }
                    }
                }
            );
        });
    }

    stopScan() {
        this.manager.stopDeviceScan();
    }

    connectToReactor(id) {
        this.manager.stopDeviceScan();
        this.isConnecting = true;
        return new Promise((resolve, reject) => {
            this.manager.connectToDevice(id)
                .then((device) => {
                    return this.fetchServicesAndCharacteristics(device);
                })
                .then((services) => {
                    this.isConnecting = false;
                    for (let i in services) {
                        let characteristics = services[i].characteristics;
                        for (let j in characteristics) {
                            if (characteristics[j].isReadable) {
                                this.readServiceUUIDs.push(services[i].uuid);
                                this.readCharacteristicUUIDs.push(characteristics[j].uuid);
                            }
                            if (characteristics[j].isWritableWithResponse) {
                                this.writeWithResponseServiceUUIDs.push(services[i].uuid);
                                this.writeWithResponseCharacteristicUUIDs.push(characteristics[j].uuid);
                            }
                            if (characteristics[j].isWritableWithoutResponse) {
                                this.writeWithoutResponseServiceUUIDs.push(services[i].uuid);
                                this.writeWithoutResponseCharacteristicUUIDs.push(characteristics[j].uuid);
                            }
                            if (characteristics[j].isNotifiable) {
                                this.notifyServiceUUIDs.push(services[i].uuid);
                                this.notifyCharacteristicUUIDs.push(characteristics[j].uuid);
                            }
                        }
                    }
                    resolve();
                })
                .catch((err) => {
                    //console.log("BleUtilities - connectToReactor error:", err);
                    this.isConnecting = false;
                    reject(err);
                })
        });
    }

    monitorCharacteristic(bleId, transactionId, serviceUUID, characteristicUUID, listener) {
        this.manager.monitorCharacteristicForDevice(
            bleId,
            serviceUUID,
            characteristicUUID,
            (error, characteristic) => {
                if (error) {
                    //console.log("BleUtlities - monitorCharacteristic error:",error);
                    listener(error);
                    return;
                }
                else if (characteristic) {
                    const buffer = Buffer.from(characteristic.value, 'base64');
                    const byteArray = Array.from(buffer);
                    listener(byteArray);
                    return;
                }
            },
            transactionId
        )
    }

    cancelMonitor(powerId, colorId, reactionsId, updateId) {
        this.manager.cancelTransaction(powerId);
        this.manager.cancelTransaction(colorId);
        this.manager.cancelTransaction(reactionsId);
        this.manager.cancelTransaction(updateId);
        //console.log("BleUtilities - characteristic monitoring stopped:", powerId, colorId, reactionsId, updateId);
    }

    disconnectFromReactor(id) {
        return new Promise((resolve, reject) => {
            //console.log("ReactorBLE - Disconnecting from Reactor", id, "...");
            this.manager.cancelDeviceConnection(id)
                .then((res) => {
                    //console.log("BleUtitlities disconnectFromReactor - Done");
                    resolve(res);
                })
                .catch((err) => {
                    //console.log("BleUtilities - disconnectFromReactor error:", err);
                    reject(err);
                })
        });
    }

    async fetchServicesAndCharacteristics(device) {
        let servicesMap = {};
        await device.discoverAllServicesAndCharacteristics();
        let services = await device.services();
        for (let service of services) {
            let characteristicsMap = {};
            let characteristics = await service.characteristics();
            for (let characteristic of characteristics) {
                characteristicsMap[characteristic.uuid] = {
                    uuid: characteristic.uuid,
                    isReadable: characteristic.isReadable,
                    isWritableWithResponse: characteristic.isWritableWithResponse,
                    isWritableWithoutResponse: characteristic.isWritableWithoutResponse,
                    isNotifiable: characteristic.isNotifiable,
                    isNotifying: characteristic.isNotifying,
                    value: characteristic.value
                };
            }
            servicesMap[service.uuid] = {
                uuid: service.uuid,
                isPrimary: service.isPrimary,
                characteristics: characteristicsMap
            };
        }
        return servicesMap;
    }

    getFullUUID(uuid) {
        return fullUUID(uuid);
    }

    readCharacteristicValue(reactorId, serviceUUID, characteristicUUID) {
        const transactionId = reactorId + ":reacCharacteristicValue"
        return new Promise((resolve, reject) => {
            this.manager.readCharacteristicForDevice(reactorId, serviceUUID, characteristicUUID, transactionId)
                .then(characteristic => {
                    const buffer = Buffer.from(characteristic.value, 'base64');
                    const byteArray = Array.from(buffer);
                    resolve(byteArray);
                }, (error) => {
                    //console.log("BleUtilities - readCharacteristicValue error:", error);
                    reject(error);
                })
        });
    }

    writeWithoutResponse(reactorId, serviceUUID, characteristicUUID, value) {
        const formatValue = Buffer.from(value, 'ascii').toString('base64');
        const transactionId = reactorId + ':writeWithoutResponse';
        return new Promise((resolve, reject) => {
            this.manager.writeCharacteristicWithoutResponseForDevice(
                reactorId,
                serviceUUID,
                characteristicUUID,
                formatValue,
                transactionId
            ).then((characteristic) => {
                resolve(characteristic.value);
            }, (error) => {
                //console.log("BleUtilities - writeWithoutResponse error:", error);
                reject(error);
            });
        });
    }

    compileColorValue(mode, control, color) {
        const lightMode = mode === "Head" ? "H" : (mode === "Tail" ? "T" : "G");
        const colorControl = `${control}`;
        const mainColor = color < 10 ? `00${color}` : (color < 100 ? `0${color}` : `${color}`);
        const value = lightMode + colorControl + mainColor;
        return value;
    }

    compilePowerValue(mode, bright, rate) {
        const powerMode = mode === "Day" ? "D" : (mode === "Strobe" ? "S" : "F");
        const brightness = bright >= 10 ? `${bright}` : `0${bright}`;
        const strobeRate = rate >= 10 ? `${rate}` : `0${rate}`;
        const value = powerMode + brightness + strobeRate;
        return value;
    }

    compileReactionValue(brake, turn, x2b, crash) {
        const brakeMode = brake === "Disabled" ? "0" : "1";
        const turnMode = turn === "Disabled" ? "0" : "1";
        const x2bMode = x2b === "Disabled" ? "0" : "1";
        const crashMode = crash === "Disabled" ? "0" : "1";
        const value = brakeMode + turnMode + x2bMode + crashMode;
        return value;
    }

    stringToByte(str) {
        var bytes = new Array();
        var len, c;
        len = str.length;
        for (var i = 0; i < len; i++) {
            c = str.charCodeAt(i);
            if (c >= 0x010000 && c <= 0x10FFFF) {
                bytes.push(((c >> 18) & 0x07) | 0xF0);
                bytes.push(((c >> 12) & 0x3F) | 0x80);
                bytes.push(((c >> 6) & 0x3F) | 0x80);
                bytes.push((c & 0x3F) | 0x80);
            } else if (c >= 0x000800 && c <= 0x00FFFF) {
                bytes.push(((c >> 12) & 0x0F) | 0xE0);
                bytes.push(((c >> 6) & 0x3F) | 0x80);
                bytes.push((c & 0x3F) | 0x80);
            } else if (c >= 0x000080 && c <= 0x0007FF) {
                bytes.push(((c >> 6) & 0x1F) | 0xC0);
                bytes.push((c & 0x3F) | 0x80);
            } else {
                bytes.push(c & 0xFF);
            }
        }
        return bytes;
    }

    byteToString(arr) {
        if (typeof arr === 'string') {
            return arr;
        }
        var str = '',
            _arr = arr;
        for (var i = 0; i < _arr.length; i++) {
            var one = _arr[i].toString(2),
                v = one.match(/^1+?(?=0)/);
            if (v && one.length == 8) {
                var bytesLength = v[0].length;
                var store = _arr[i].toString(2).slice(7 - bytesLength);
                for (var st = 1; st < bytesLength; st++) {
                    store += _arr[st + i].toString(2).slice(2);
                }
                str += String.fromCharCode(parseInt(store, 2));
                i += bytesLength - 1;
            } else {
                str += String.fromCharCode(_arr[i]);
            }
        }
        return str;
    }
}