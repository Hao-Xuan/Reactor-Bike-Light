import React, { useEffect } from 'react';
import { TouchableOpacity } from 'react-native';
import { useDispatch, useSelector } from 'react-redux';
import { MaterialCommunityIcons } from '@expo/vector-icons';

import { turnPowerOff } from '../../store/actions/reactors';

const PowerControl = (props) => {
    const [batteryLevel, powerSync, bleId] = useSelector(
        (state) => state.reactors.reactors.filter(
            (reactor) => (reactor.dbId === props.id)
        ).flatMap(
            (reactor) => [reactor.batteryLevel, reactor.powerSync, reactor.bleId]
        )
    );
    const powerSyncIds = useSelector(
        (state) => state.reactors.reactors.filter(
            (reactor) => (reactor.powerOn && reactor.powerSync)
        ).map(
            (reactor) => reactor.bleId
        )
    );
    const batteryPercent = (batteryLevel>4000) ? 100 : ((batteryLevel<3010) ? 1 : (batteryLevel-3000)/10);
    const dispatch = useDispatch();
    const toggleHandler = () => {
        dispatch(turnPowerOff(
            props.id,
            powerSync ? powerSyncIds : [bleId]
        ));
    };
    useEffect(() => {
        if (batteryLevel === 0) {
            dispatch(turnPowerOff(
                props.id,
                [bleId]
            ));
        }
    }, [batteryLevel]);
    return (
        <TouchableOpacity
                onPress={toggleHandler}
            >
                <MaterialCommunityIcons
                    name={'power'}
                    size={50}
                    color={`hsl(${120 * batteryPercent / 100}, 100%, 50%)`}
                />
            </TouchableOpacity>
    );
};

export default PowerControl;