import React from 'react';
import { View, StyleSheet, Text } from 'react-native';
import { useSelector } from 'react-redux';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import Colors from '../../constants/Colors';

const ThermIndicator = (props) => {
    const therm = useSelector(
            state => state.reactors.reactors.find(
                (reactor) => (reactor.dbId === props.id)
            ).therm
        );
    return (
        <View style={styles.contentContainer} >
            <MaterialCommunityIcons
                name= {(therm<345) 
                    ? 'thermometer-low' 
                    : (therm<495) 
                        ? 'thermometer' 
                        : 'thermometer-high'}
                size={20}
                color={(therm<295) 
                    ? `hsl(240, 100%, 50%)` 
                    : (therm<445) 
                        ? `hsl(60, 100%, 50%)` 
                        : (therm<595) 
                            ? `hsl(30, 100%, 50%)` 
                            : `hsl(0, 100%, 50%)`}
            />
            <Text style={styles.text}>{Number.parseFloat(therm/10).toFixed(0)}C</Text>
        </View>
    );
};

const styles = StyleSheet.create({
    contentContainer: {
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'center',
        height: 20,
        width: 60
    },
    text: {
        fontSize: 20,
        color: Colors.backgroundText
    },
        
});

export default ThermIndicator;