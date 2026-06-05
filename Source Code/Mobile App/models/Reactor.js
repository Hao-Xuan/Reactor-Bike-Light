class Reactor {
    constructor(
        dbId,           //string - unique numeric (decimal) id
        bleId,          //string - unique alphanumeric (hex) id
        focused,        //bool
        powerOn,        //bool
        isScanned,      //bool
        isLinked,       //bool
        lightMode,      //string - enum (Head, Ground, Tail)
        colorSync,      //bool
        colorMode,      //int 0-2
        mainColor,      //int 0-764
        powerSync,      //bool
        powerMode,      //string - enum (Day, Strobe, Full)
        brightness,     //int 0-3
        strobeRate,     //int 0-3
        batteryLevel,   //int 0-100
        therm,          //int 
        firmware,       //string - firmware revision number
        updateProgress, //int 0-101
    ) {
        this.dbId = dbId;
        this.bleId = bleId;
        this.focused = focused;
        this.powerOn = powerOn;
        this.isScanned = isScanned;
        this.isLinked = isLinked;
        this.lightMode = lightMode;
        this.colorSync = colorSync;
        this.colorMode = colorMode;
        this.mainColor = mainColor;
        this.powerSync = powerSync;
        this.powerMode = powerMode;
        this.brightness = brightness;
        this.strobeRate = strobeRate;
        this.batteryLevel = batteryLevel;
        this.therm = therm;
        this.firmware = firmware;
        this.updateProgress = updateProgress;
    }
}

export default Reactor;