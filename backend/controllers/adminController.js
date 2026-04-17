const db = require('../db');

exports.approvePlayer = async (req, res) => {
    const { id } = req.params; // Get the player ID from the URL

    try {
        const [result] = await db.query(
            "UPDATE users SET status = 'active' WHERE id = ? AND type = 'player'",
            [id]
        );

        if (result.affectedRows === 0) {
            return res.status(404).json({ message: "Player not found or user is not a player." });
        }

        res.status(200).json({ message: `Player ${id} has been approved.` });
    } catch (error) {
        console.error("Approval Error:", error);
        res.status(500).json({ message: "Server error during approval." });
    }
};
