import Foundation

/// The built-in exercise library. UUIDs are stable across releases —
/// seeding matches on UUID, so entries can be renamed or appended in a
/// future seed version without duplicating user data.
enum ExerciseSeedData {
    static let all: [SeedExercise] = [

        // MARK: Chest
        SeedExercise(uuidString: "7385E011-193B-5E62-ABBD-865F3E9F5485", name: "Barbell Bench Press", muscleGroup: .chest, equipment: .barbell),
        SeedExercise(uuidString: "AF5CCA18-3A14-5F8D-BA3C-10A2B0486276", name: "Incline Barbell Bench Press", muscleGroup: .chest, equipment: .barbell),
        SeedExercise(uuidString: "9666001F-F84C-5A2D-9E27-6AC6AD6B6E03", name: "Dumbbell Bench Press", muscleGroup: .chest, equipment: .dumbbell),
        SeedExercise(uuidString: "0B452F98-4747-507D-A0DF-16512DECA500", name: "Incline Dumbbell Press", muscleGroup: .chest, equipment: .dumbbell),
        SeedExercise(uuidString: "6A30E38B-9E63-5BA2-A7DF-2671A4D68F6B", name: "Dumbbell Fly", muscleGroup: .chest, equipment: .dumbbell),
        SeedExercise(uuidString: "27B8F370-FF74-5CFE-9C36-C76D3D10803D", name: "Cable Crossover", muscleGroup: .chest, equipment: .cable),
        SeedExercise(uuidString: "89DD9C31-B927-510A-89DE-B14B70FF1E31", name: "Chest Press Machine", muscleGroup: .chest, equipment: .machine),
        SeedExercise(uuidString: "7A8F3779-A245-5B5E-8F97-93CF39021416", name: "Pec Deck", muscleGroup: .chest, equipment: .machine),
        SeedExercise(uuidString: "056346BC-F4A1-5AF0-BE70-DFFDB9763C29", name: "Push-Up", muscleGroup: .chest, equipment: .bodyweight),
        SeedExercise(uuidString: "42414A69-E0B4-52BF-8C57-C99D0A31A4F0", name: "Dip", muscleGroup: .chest, equipment: .bodyweight),

        // MARK: Back
        SeedExercise(uuidString: "8980FE57-9970-5334-906C-A6828FC3DA40", name: "Deadlift", muscleGroup: .back, equipment: .barbell),
        SeedExercise(uuidString: "A2CF3B21-F250-572E-A482-E3E19F43725E", name: "Barbell Row", muscleGroup: .back, equipment: .barbell),
        SeedExercise(uuidString: "B4EBEA46-41C0-5EB3-8415-7273869E4B3B", name: "T-Bar Row", muscleGroup: .back, equipment: .barbell),
        SeedExercise(uuidString: "F0D1285E-276F-563E-BB78-886CF74146FF", name: "Rack Pull", muscleGroup: .back, equipment: .barbell),
        SeedExercise(uuidString: "57C5432F-E42A-5903-A5E2-8CA1C415C93D", name: "Pull-Up", muscleGroup: .back, equipment: .bodyweight),
        SeedExercise(uuidString: "48836B72-0CE6-50E2-9A3F-0E569E805C6A", name: "Chin-Up", muscleGroup: .back, equipment: .bodyweight),
        SeedExercise(uuidString: "550E0397-2094-5E43-B486-35A0DAE983A7", name: "Lat Pulldown", muscleGroup: .back, equipment: .cable),
        SeedExercise(uuidString: "D250E85A-D216-537B-9BE3-A237FA797F70", name: "Seated Cable Row", muscleGroup: .back, equipment: .cable),
        SeedExercise(uuidString: "EDD2591D-23CB-547F-9F83-37CF0FFDF0AE", name: "Straight-Arm Pulldown", muscleGroup: .back, equipment: .cable),
        SeedExercise(uuidString: "A296078C-BAA5-58DA-AEDE-6D48124E627B", name: "Face Pull", muscleGroup: .back, equipment: .cable),
        SeedExercise(uuidString: "09BA1F5C-A64A-525B-9200-F4AB28991F12", name: "Dumbbell Row", muscleGroup: .back, equipment: .dumbbell),
        SeedExercise(uuidString: "DF6A13E0-656F-5061-9D73-E0770A5F47C0", name: "Back Extension", muscleGroup: .back, equipment: .bodyweight),

        // MARK: Legs
        SeedExercise(uuidString: "155A65B7-74AC-5F34-9C53-D001C0ECD3DB", name: "Barbell Back Squat", muscleGroup: .legs, equipment: .barbell),
        SeedExercise(uuidString: "05A644CB-2A70-5453-88A1-86FA48C881A7", name: "Front Squat", muscleGroup: .legs, equipment: .barbell),
        SeedExercise(uuidString: "A833474B-D1E5-5AA5-B4BA-AF4AFDA0F8F1", name: "Romanian Deadlift", muscleGroup: .legs, equipment: .barbell),
        SeedExercise(uuidString: "2B0F3D27-F2F5-5B5E-81B3-A31883DABD91", name: "Hip Thrust", muscleGroup: .legs, equipment: .barbell),
        SeedExercise(uuidString: "A865437F-1211-51FB-8DC7-FF8E8FFAEC0A", name: "Leg Press", muscleGroup: .legs, equipment: .machine),
        SeedExercise(uuidString: "3FC83AB2-AFF6-521F-934E-7E137AC72609", name: "Hack Squat", muscleGroup: .legs, equipment: .machine),
        SeedExercise(uuidString: "FC17A068-EAF9-5D9A-AAAD-5F5EF951D8E7", name: "Leg Extension", muscleGroup: .legs, equipment: .machine),
        SeedExercise(uuidString: "55189712-DEEC-5ED9-B406-77D0DD0DD465", name: "Lying Leg Curl", muscleGroup: .legs, equipment: .machine),
        SeedExercise(uuidString: "947E5586-19EE-51D3-9733-B2A3646535A1", name: "Seated Leg Curl", muscleGroup: .legs, equipment: .machine),
        SeedExercise(uuidString: "FF9FD2D5-F760-5106-8788-FAD6E6432746", name: "Standing Calf Raise", muscleGroup: .legs, equipment: .machine),
        SeedExercise(uuidString: "94BF333D-CB74-5930-9D04-AB5A95E0FF83", name: "Seated Calf Raise", muscleGroup: .legs, equipment: .machine),
        SeedExercise(uuidString: "6180C32A-F826-565E-BFFD-645714DBE942", name: "Bulgarian Split Squat", muscleGroup: .legs, equipment: .dumbbell),
        SeedExercise(uuidString: "DB51E5B9-D60B-5938-8238-90D32F95F176", name: "Walking Lunge", muscleGroup: .legs, equipment: .dumbbell),
        SeedExercise(uuidString: "CC29BE9C-5897-58E0-AE28-9C3B334B6259", name: "Goblet Squat", muscleGroup: .legs, equipment: .dumbbell),

        // MARK: Shoulders
        SeedExercise(uuidString: "33AB1181-1FE5-52AF-8B2B-89C33E25A45E", name: "Overhead Press", muscleGroup: .shoulders, equipment: .barbell),
        SeedExercise(uuidString: "9FC69A32-81F8-551A-84B2-878982F6D7EC", name: "Upright Row", muscleGroup: .shoulders, equipment: .barbell),
        SeedExercise(uuidString: "11A38907-4467-5A93-8C87-3EA249141157", name: "Seated Dumbbell Shoulder Press", muscleGroup: .shoulders, equipment: .dumbbell),
        SeedExercise(uuidString: "AAE42EDE-654F-5821-AD54-10787A025A0D", name: "Arnold Press", muscleGroup: .shoulders, equipment: .dumbbell),
        SeedExercise(uuidString: "6FAC7FEC-F9B9-5CAB-AA9A-648872BCD8C0", name: "Lateral Raise", muscleGroup: .shoulders, equipment: .dumbbell),
        SeedExercise(uuidString: "45D89511-1E0A-5535-8767-93BEEB17F896", name: "Front Raise", muscleGroup: .shoulders, equipment: .dumbbell),
        SeedExercise(uuidString: "C5FA3BA1-EB72-57AF-B1C7-30410ED9B2B6", name: "Rear Delt Fly", muscleGroup: .shoulders, equipment: .dumbbell),
        SeedExercise(uuidString: "53136C11-9738-58C8-A879-939B7BDF4237", name: "Cable Lateral Raise", muscleGroup: .shoulders, equipment: .cable),

        // MARK: Arms
        SeedExercise(uuidString: "178345CF-8B8F-5D61-A1FF-B63B02B621F9", name: "Barbell Curl", muscleGroup: .arms, equipment: .barbell),
        SeedExercise(uuidString: "6612A57C-B02C-5B5B-A305-2C2777FF5D00", name: "Close-Grip Bench Press", muscleGroup: .arms, equipment: .barbell),
        SeedExercise(uuidString: "47F052E8-407B-5C78-B006-3253BAABD562", name: "Skull Crusher", muscleGroup: .arms, equipment: .barbell),
        SeedExercise(uuidString: "389A7BE7-4EE9-5188-BFD4-CEFD898ACDBA", name: "Dumbbell Curl", muscleGroup: .arms, equipment: .dumbbell),
        SeedExercise(uuidString: "C835C6D7-A65E-5DA1-B95C-5C363F73ADD7", name: "Hammer Curl", muscleGroup: .arms, equipment: .dumbbell),
        SeedExercise(uuidString: "379E3580-A611-515B-83FC-7D4B84D5B2F2", name: "Concentration Curl", muscleGroup: .arms, equipment: .dumbbell),
        SeedExercise(uuidString: "25B512ED-F327-50AC-81B3-DDE7A364D3B6", name: "Overhead Triceps Extension", muscleGroup: .arms, equipment: .dumbbell),
        SeedExercise(uuidString: "B71E8B13-6C63-5546-A46C-28BBDEB5BC89", name: "Preacher Curl", muscleGroup: .arms, equipment: .machine),
        SeedExercise(uuidString: "B7FEE7DF-8FD6-5A97-AF50-691FE708AA53", name: "Cable Curl", muscleGroup: .arms, equipment: .cable),
        SeedExercise(uuidString: "FA7F04FB-F5CE-568E-9686-EAAD2DB095DC", name: "Triceps Pushdown", muscleGroup: .arms, equipment: .cable),

        // MARK: Core
        SeedExercise(uuidString: "835BB0AD-3004-581F-808B-7E6309258BCE", name: "Plank", muscleGroup: .core, equipment: .bodyweight, measurement: .duration),
        SeedExercise(uuidString: "B134B600-21A9-556B-899D-C315F54B9327", name: "Side Plank", muscleGroup: .core, equipment: .bodyweight, measurement: .duration),
        SeedExercise(uuidString: "930C5FFB-F531-529D-A834-C7D1443F960A", name: "Crunch", muscleGroup: .core, equipment: .bodyweight),
        SeedExercise(uuidString: "A4048060-B081-56BD-A954-8AE1191E919D", name: "Hanging Leg Raise", muscleGroup: .core, equipment: .bodyweight),
        SeedExercise(uuidString: "5EB78BE0-029E-58E9-B0F1-C33C2D5C9E4A", name: "Russian Twist", muscleGroup: .core, equipment: .bodyweight),
        SeedExercise(uuidString: "8C8289F5-5E37-5200-B86B-522C38E6075C", name: "Mountain Climber", muscleGroup: .core, equipment: .bodyweight),
        SeedExercise(uuidString: "C5E7CDAB-5BC5-5EE5-9E08-FDC21D6F891D", name: "Cable Crunch", muscleGroup: .core, equipment: .cable),
        SeedExercise(uuidString: "2061DB6E-6B9F-5EA2-99B4-2BD6B63246E9", name: "Ab Wheel Rollout", muscleGroup: .core, equipment: .other),

        // MARK: Cardio
        SeedExercise(uuidString: "75099DCF-3694-5CCD-A456-6BCE82386862", name: "Treadmill Run", muscleGroup: .cardio, equipment: .machine),
        SeedExercise(uuidString: "FE616560-7BDD-521D-B11E-E1727FA21EEE", name: "Stationary Bike", muscleGroup: .cardio, equipment: .machine),
        SeedExercise(uuidString: "784E53EE-E446-59E2-9895-F226D0685DE0", name: "Rowing Machine", muscleGroup: .cardio, equipment: .machine),
        SeedExercise(uuidString: "6AFCA2AC-FD6D-52EC-80BD-4B63C8C7A1C1", name: "Stair Climber", muscleGroup: .cardio, equipment: .machine),
        SeedExercise(uuidString: "B7B8CE37-58A3-58A2-A6A3-F740ADBA0AF9", name: "Elliptical", muscleGroup: .cardio, equipment: .machine),
        SeedExercise(uuidString: "B30E9102-830C-550E-AC60-A47045766DC0", name: "Jump Rope", muscleGroup: .cardio, equipment: .other),
    ]
}
