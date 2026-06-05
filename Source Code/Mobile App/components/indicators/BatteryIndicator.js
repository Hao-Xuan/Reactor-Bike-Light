import React from 'react';
import { useSelector } from 'react-redux';
import { MaterialCommunityIcons } from '@expo/vector-icons';

const BatteryIndicator = (props) => {
    const batteryLevel = useSelector(
        state => state.reactors.reactors.find(
            (reactor) => (reactor.dbId === props.id)
        ).batteryLevel
    );
    const batteryPercent = (batteryLevel<3010) 
        ? 1 
        : (batteryLevel<4000) 
            ? (batteryLevel-3000)/10 
            : 100;
    const level = 10 * Math.round(batteryPercent / 10);    
    const batteryColor = `hsl(${120 * batteryPercent / 100}, 100%, 50%)`;
    return (
        <MaterialCommunityIcons
            name={(level === 100)
                ? 'battery'
                : (level === 0)
                    ? 'battery-alert-variant-outline'
                    : `battery-${level}`}
            size={40}
            color={batteryColor}
        /> 
    );
};

export default BatteryIndicator;