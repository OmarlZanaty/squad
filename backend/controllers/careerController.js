const db = require('../db');

// Add a career history entry
exports.addCareerEntry = async (req, res) => {
    const userId = req.user.id;
    const { club_name, years, position, achievements } = req.body;

    // Validation
    if (!club_name || !years) {
        return res.status(400).json({ message: "Club name and years are required." });
    }

    try {
        const sql = "INSERT INTO career_history (user_id, club_name, years, position, achievements) VALUES (?, ?, ?, ?, ?)";
        const [result] = await db.query(sql, [userId, club_name, years, position, achievements]);

        res.status(201).json({ 
            message: "Career entry added successfully.",
            entry_id: result.insertId
        });

    } catch (error) {
        console.error("Add Career Entry Error:", error);
        res.status(500).json({ message: "Server error while adding career entry." });
    }
};

// Get all career history for a user
exports.getCareerHistory = async (req, res) => {
    const { userId } = req.params;

    try {
        const [entries] = await db.query(
            "SELECT id, club_name, years, position, achievements, created_at FROM career_history WHERE user_id = ? ORDER BY created_at DESC",
            [userId]
        );

        res.status(200).json(entries);

    } catch (error) {
        console.error("Get Career History Error:", error);
        res.status(500).json({ message: "Server error while fetching career history." });
    }
};

// Update a career history entry
exports.updateCareerEntry = async (req, res) => {
    const userId = req.user.id;
    const { entryId } = req.params;
    const { club_name, years, position, achievements } = req.body;

    try {
        // Verify the entry belongs to the user
        const [entries] = await db.query(
            "SELECT id FROM career_history WHERE id = ? AND user_id = ?",
            [entryId, userId]
        );

        if (entries.length === 0) {
            return res.status(404).json({ message: "Career entry not found or you don't have permission." });
        }

        // Build dynamic update query
        let updates = [];
        let values = [];

        if (club_name) {
            updates.push("club_name = ?");
            values.push(club_name);
        }
        if (years) {
            updates.push("years = ?");
            values.push(years);
        }
        if (position !== undefined) {
            updates.push("position = ?");
            values.push(position);
        }
        if (achievements !== undefined) {
            updates.push("achievements = ?");
            values.push(achievements);
        }

        if (updates.length === 0) {
            return res.status(400).json({ message: "No fields to update." });
        }

        values.push(entryId);
        const sql = `UPDATE career_history SET ${updates.join(', ')} WHERE id = ?`;

        await db.query(sql, values);

        res.status(200).json({ message: "Career entry updated successfully." });

    } catch (error) {
        console.error("Update Career Entry Error:", error);
        res.status(500).json({ message: "Server error while updating career entry." });
    }
};

// Delete a career history entry
exports.deleteCareerEntry = async (req, res) => {
    const userId = req.user.id;
    const { entryId } = req.params;

    try {
        // Verify the entry belongs to the user
        const [result] = await db.query(
            "DELETE FROM career_history WHERE id = ? AND user_id = ?",
            [entryId, userId]
        );

        if (result.affectedRows === 0) {
            return res.status(404).json({ message: "Career entry not found or you don't have permission." });
        }

        res.status(200).json({ message: "Career entry deleted successfully." });

    } catch (error) {
        console.error("Delete Career Entry Error:", error);
        res.status(500).json({ message: "Server error while deleting career entry." });
    }
};
