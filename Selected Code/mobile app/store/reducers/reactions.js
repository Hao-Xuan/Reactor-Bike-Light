import {
    TOGGLE_LEFT_TURN,
    TOGGLE_RIGHT_TURN,
    TOGGLE_X2B,
    REMOVE_CONTACT,
    ADD_CONTACT,
    SET_CONTACTS,
    ADD_CRASH,
    SET_CRASHES
} from '../actions/reactions';

import {
    UPDATE_REACTIONS,
    CLEAR_REACTION_UPDATE_ID
} from '../actions/reactors';

import Contact from '../../models/Contact';
import Crash from '../../models/Crash';

const initialState = {
    brakeActive: false,
    leftTurnActive: false,
    rightTurnActive: false,
    x2bActive: false,
    crashActive: false,
    reactionUpdateId: null,
    crashContacts: [],
    crashHistory: []
};

const reactionsReducer = (state = initialState, action) => {
    let updatedCrashContacts = state.crashContacts;
    let updatedCrashHistory = state.crashHistory;
    switch (action.type) {
        case UPDATE_REACTIONS:
            if (
                state.reactionUpdateId
                || ((state.brakeActive === action.brakeActive)
                    && (state.leftTurnActive === action.leftTurnActive)
                    && (state.rightTurnActive === action.rightTurnActive)
                    && (state.x2bActive === action.x2bActive)
                    && (state.crashActive === action.crashActive))
            ) {
                //console.log("Reactions reducer - skipping reaction update from Reactor:",action.reactionUpdateId);
                return {
                    ...state
                };
            }
            return {
                ...state,
                brakeActive: action.brakeActive,
                leftTurnActive: action.leftTurnActive,
                rightTurnActive: action.rightTurnActive,
                x2bActive: action.x2bActive,
                crashActive: action.crashActive,
                reactionUpdateId: action.reactionUpdateId
            };
        case TOGGLE_LEFT_TURN:
            return {
                ...state,
                leftTurnActive: !state.leftTurnActive,
                rightTurnActive: false,
                reactionUpdateId: "emptyId"
            };
        case TOGGLE_RIGHT_TURN:
            return {
                ...state,
                leftTurnActive: false,
                rightTurnActive: !state.rightTurnActive,
                reactionUpdateId: "emptyId"
            };
        case TOGGLE_X2B:
            return {
                ...state,
                leftTurnActive: (state.crashActive || !state.x2bActive) ? false : state.leftTurnActive,
                rightTurnActive: (state.crashActive || !state.x2bActive) ? false : state.rightTurnActive,
                x2bActive: state.crashActive ? false : !state.x2bActive,
                reactionUpdateId: "emptyId"
            };
        case REMOVE_CONTACT:
            updatedCrashContacts = updatedCrashContacts.filter(
                contact => contact.number !== action.number
            );
            return {
                ...state,
                crashContacts: updatedCrashContacts
            };
        case ADD_CONTACT:
            updatedCrashContacts.push(
                new Contact(
                    action.id,
                    action.name,
                    action.number
                ));
            return {
                ...state,
                crashContacts: updatedCrashContacts
            };
        case SET_CONTACTS:
            for (let idx = 0; idx < action.contacts.length; idx++) {
                updatedCrashContacts.push(
                    new Contact(
                        action.contacts[idx].id,
                        action.contacts[idx].name,
                        action.contacts[idx].number
                    )
                );
            }
            return {
                ...state,
                crashContacts: updatedCrashContacts
            };
        case ADD_CRASH:
            const newCrash = new Crash(
                action.dbId,
                action.time,
                action.latitude,
                action.longitude,
                action.altitude,
                action.notifiedContacts,
                action.message
            );
            updatedCrashHistory.push(newCrash);
            return {
                ...state,
                crashHistory: updatedCrashHistory
            };
        case SET_CRASHES:
            const loadedCrashes = action.dbCrashes.map(
                crash => new Crash(
                    crash.dbId,
                    crash.time,
                    crash.latitude,
                    crash.longitude,
                    crash.altitude,
                    crash.notifiedContacts,
                    crash.message
                )
            );
            return {
                ...state,
                crashHistory: loadedCrashes
            };
        case CLEAR_REACTION_UPDATE_ID:
            return {
                ...state,
                reactionUpdateId: null
            };
        default:
            return state;
    }
};

export default reactionsReducer;