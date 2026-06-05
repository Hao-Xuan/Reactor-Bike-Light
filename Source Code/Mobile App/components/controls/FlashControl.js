import React, { useState, useEffect } from 'react';
import { TouchableOpacity, StyleSheet } from 'react-native';
import { useDispatch, useSelector } from 'react-redux';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import Colors from '../../constants/Colors';

import { toggleX2b } from '../../store/actions/reactions';

const FlashControl = (props) => {
    const flashActive = useSelector(
        state => state.reactions.x2bActive
    );
    const strobeRate = useSelector(
        state => state.reactors.reactors.find(
            reactor => (reactor.dbId === props.id)
        ).strobeRate
    );
    const dispatch = useDispatch();
    const toggleHandler = () => {
        dispatch(toggleX2b());
    };
    const [strobeHigh, setStrobeHigh] = useState(false);
    useEffect(() => {
        if (flashActive) {
            const strobeTime = 500- 9000 * strobeRate / 64;
            const timerId = setTimeout(() => {
                setStrobeHigh(!strobeHigh);
            }, strobeTime);
            return () => clearTimeout(timerId);
        } else {
            setStrobeHigh(false);
        }
    }, [flashActive, strobeHigh, strobeRate]);
    return (
        <TouchableOpacity
            style={styles.contentContainer}
            onPress={toggleHandler}
        >
            <MaterialCommunityIcons
                name={strobeHigh ? 'alert' : 'alert-outline'}
                size={flashActive ? 50 : 40}
                color={Colors.crashColor}
            />
        </TouchableOpacity>
    );
};

const styles = StyleSheet.create({
    contentContainer: {
        alignItems: 'center',
        justifyContent: 'center',
        height: 50,
        width: 50,
        marginTop: '10%'
    }
});

export default FlashControl;