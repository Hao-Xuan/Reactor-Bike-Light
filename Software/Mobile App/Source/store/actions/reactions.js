import SmsAndroid from 'react-native-get-sms-android';

import {
    fetchContacts,
    insertContact,
    deleteContact
} from "../../helpers/contactsDB";

import {
    fetchCrashes,
    insertCrash
} from "../../helpers/crashesDB";

export const TOGGLE_LEFT_TURN = 'TOGGLE_LEFT_TURN';
export const TOGGLE_RIGHT_TURN = 'TOGGLE_RIGHT_TURN';
export const TOGGLE_X2B = 'TOGGLE_X2B';
export const TOGGLE_PHONE_NUMBER = 'TOGGLE_PHONE_NUMBER';
export const REMOVE_CONTACT = 'REMOVE_CONTACT';
export const ADD_CONTACT = 'ADD_CONTACT';
export const SET_CONTACTS = 'SET_CONTACTS';
export const ADD_CRASH = 'ADD_CRASH';
export const SET_CRASHES = 'SET_CRASHES';

export const toggleLeftTurn = () => {
    return {
        type: TOGGLE_LEFT_TURN
    };
};

export const toggleRightTurn = () => {
    return {
        type: TOGGLE_RIGHT_TURN
    };
};

export const toggleX2b = () => {
    return {
        type: TOGGLE_X2B
    };
};

export const removeContact = (number) => {
    return async dispatch => {
        try {
            await deleteContact(number);
            dispatch({
                type: REMOVE_CONTACT,
                number: number
            });
        } catch (err) {
            throw err;
        }
    }
};

export const addContact = (name, number) => {
    return async dispatch => {
        try {
            const dbResult = await insertContact(name, number);
            dispatch({
                type: ADD_CONTACT,
                id: dbResult.insertId,
                name: name,
                number: number
            });
        } catch (err) {
            throw err;
        }
        //console.log("Reactions actions - ADD_CONTACT:",contact);
    }
};

export const loadContacts = () => {
    return async dispatch => {
        try {
            const dbResult = await fetchContacts();
            dispatch({
                type: SET_CONTACTS,
                contacts: dbResult
            });
        } catch (err) {
            throw err;
        }
    };
};

function sendSms(number, message) {
    const promise = new Promise((resolve, reject) => {
        SmsAndroid.autoSend(
            number,
            message,
            (fail) => {
                reject(fail);
            },
            (success) => {
                resolve(success);
            }
        );
    });
    return promise;
}

export const recordNewCrash = (time, location, contacts) => {
    return async dispatch => {
        try {
            const latitude = location.coords.latitude.toFixed(5);
            const longitude = location.coords.longitude.toFixed(5);
            const altitude = location.coords.altitude.toFixed(5);
            const message = "My Reactor Bike Light has detected a crash! "
                + "Please follow the link to see my location.\n\n"
                + `https://www.google.com/maps/search/?api=1&query=${latitude},${longitude}`
                + "\n\nThis message was sent automatically.";
            let notifiedContacts = "";
            if (contacts.length > 0) {
                for (let idx = 0; idx < contacts.length; idx++) {
                    const smsStatus = await sendSms(contacts[idx].number, message);
                    if (smsStatus === 'SMS sent') {
                        notifiedContacts += contacts[idx].name + "," + contacts[idx].number + ",";
                        console.log("Reactions actions -", smsStatus, ":", contacts[idx]);
                    }
                }
            }
            //console.log("Reactions actions - notified contacts:", notifiedContacts);
            const dbId = await insertCrash(time, latitude, longitude, altitude, notifiedContacts, message);
            dispatch({
                type: ADD_CRASH,
                dbId: dbId,
                time: time,
                latitude: latitude,
                longitude: longitude,
                altitude: altitude,
                notifiedContacts: notifiedContacts,
                message: message
            });

        } catch (err) {
            throw err;
        }
    };
};

export const loadCrashes = () => {
    return async dispatch => {
        const dbCrashes = await fetchCrashes();
        //console.log("Reactions actions - loaded crashes:", dbCrashes);
        if (dbCrashes.length > 0) {
            dispatch({
                type: SET_CRASHES,
                dbCrashes: dbCrashes
            });
        }
    };
};