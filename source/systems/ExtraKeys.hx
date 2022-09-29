package systems;

class ExtraKeys {
    // the shit works like this:
    // the name of the thing in the xml
    // and the default colors (in rgb format)
    public static var arrowInfo:Array<Dynamic> = [
        [ // 1k
            ["space"],
            [[0, -100, 0]],
            1,
            1
        ],
        [ // 2k
            ["left", "right"],
            [[194, 75, 153], [249, 57, 63]],
            1,
            1
        ],
        [ // 3k
            ["left", "space", "right"],
            [[194, 75, 153], [204, 204, 204], [249, 57, 63]],
            1,
            1
        ],
        [ // 4k
            ["left", "down", "up", "right"],
            [[194, 75, 153], [0, 255, 255], [18, 250, 5], [249, 57, 63]],
            1,
            1
        ],
        [ // 5k
            ["left", "down", "space", "up", "right"],
            [[194, 75, 153], [0, 255, 255], [204, 204, 204], [18, 250, 5], [249, 57, 63]],
            1,
            1
        ],
        [ // 6k
            ["left", "down", "right", "left", "up", "right"],
            [[194, 75, 153], [18, 250, 5], [249, 57, 63], [255, 253, 16], [0, 255, 255], [5, 44, 246]],
            0.8,
            0.85
        ],
        [ // 7k
            ["left", "down", "right", "space", "left", "up", "right"],
            [[194, 75, 153], [18, 250, 5], [249, 57, 63], [204, 204, 204], [255, 253, 16], [0, 255, 255], [5, 44, 246]],
            0.8,
            0.85
        ],
        [ // 8k
            ["left", "down", "up", "right", "left", "down", "up", "right"],
            [[194, 75, 153], [0, 255, 255], [18, 250, 5], [249, 57, 63], [255, 253, 16], [133, 56, 248], [233, 0, 3], [5, 44, 246]],
            0.6,
            0.8
        ],
        [ // 9k
            ["left", "down", "up", "right", "space", "left", "down", "up", "right"],
            [[194, 75, 153], [0, 255, 255], [18, 250, 5], [249, 57, 63], [204, 204, 204], [255, 253, 16], [133, 56, 248], [233, 0, 3], [5, 44, 246]],
            0.6,
            0.8
        ],
    ];
}