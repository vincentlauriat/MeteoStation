import Foundation

/// Calcul lever/coucher du soleil (algorithme NOAA simplifié, précision ~1 min).
enum SolarTimes {
    static func sunriseSunset(on date: Date, latitude: Double, longitude: Double) -> (sunrise: Date?, sunset: Date?) {
        let julianDate = date.timeIntervalSince1970 / 86_400 + 2_440_587.5
        let n = (julianDate - 2_451_545.0 + 0.0008).rounded()
        let lw = -longitude // convention : longitude ouest positive

        let jStar = n + lw / 360
        let meanAnomaly = normalize(357.5291 + 0.985_600_28 * jStar)
        let m = meanAnomaly * .pi / 180
        let center = 1.9148 * sin(m) + 0.02 * sin(2 * m) + 0.0003 * sin(3 * m)
        let eclipticLongitude = normalize(meanAnomaly + center + 180 + 102.9372)
        let lambda = eclipticLongitude * .pi / 180

        let jTransit = 2_451_545.0 + jStar + 0.0053 * sin(m) - 0.0069 * sin(2 * lambda)
        let declination = asin(sin(lambda) * sin(23.44 * .pi / 180))
        let phi = latitude * .pi / 180

        // -0.83° : réfraction atmosphérique + demi-diamètre solaire.
        let cosHourAngle = (sin(-0.83 * .pi / 180) - sin(phi) * sin(declination))
            / (cos(phi) * cos(declination))
        guard cosHourAngle >= -1, cosHourAngle <= 1 else { return (nil, nil) } // jour/nuit polaire

        let hourAngle = acos(cosHourAngle) * 180 / .pi
        let jRise = jTransit - hourAngle / 360
        let jSet = jTransit + hourAngle / 360
        return (dateFromJulian(jRise), dateFromJulian(jSet))
    }

    private static func normalize(_ degrees: Double) -> Double {
        let d = degrees.truncatingRemainder(dividingBy: 360)
        return d < 0 ? d + 360 : d
    }

    private static func dateFromJulian(_ jd: Double) -> Date {
        Date(timeIntervalSince1970: (jd - 2_440_587.5) * 86_400)
    }
}
