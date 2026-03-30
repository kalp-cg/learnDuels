const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

exports.toggleSave = async (req, res) => {
    try {
        const userId = req.user.id;
        const { questionId } = req.body;

        if (!questionId) {
            return res.status(400).json({ message: 'Question ID is required' });
        }

        const existing = await prisma.savedQuestion.findUnique({
            where: {
                userId_questionId: {
                    userId,
                    questionId: parseInt(questionId),
                },
            },
        });

        if (existing) {
            // Unsave
            await prisma.savedQuestion.delete({
                where: { id: existing.id },
            });
            return res.status(200).json({ message: 'Question removed from vault', isSaved: false });
        } else {
            // Save
            await prisma.savedQuestion.create({
                data: {
                    userId,
                    questionId: parseInt(questionId),
                },
            });
            return res.status(200).json({ message: 'Question saved to vault', isSaved: true });
        }
    } catch (error) {
        console.error('Error toggling save:', error);
        res.status(500).json({ message: 'Internal server error' });
    }
};

exports.getSavedQuestions = async (req, res) => {
    try {
        const userId = req.user.id;
        const page = parseInt(req.query.page) || 1;
        const limit = parseInt(req.query.limit) || 20;
        const skip = (page - 1) * limit;

        const [saved, total] = await prisma.$transaction([
            prisma.savedQuestion.findMany({
                where: { userId },
                include: {
                    question: {
                        select: {
                            id: true,
                            content: true,
                            options: true,
                            correctAnswer: true,
                            explanation: true,
                            type: true,
                            difficulty: true,
                            topics: {
                                include: {
                                    topic: true
                                }
                            }
                        },
                    },
                },
                orderBy: { savedAt: 'desc' },
                skip,
                take: limit,
            }),
            prisma.savedQuestion.count({ where: { userId } }),
        ]);

        res.status(200).json({
            data: saved.map(s => ({
                ...s.question,
                savedAt: s.savedAt,
                note: s.note
            })),
            pagination: {
                page,
                limit,
                total,
                pages: Math.ceil(total / limit),
            },
        });
    } catch (error) {
        console.error('Error fetching saved questions:', error);
        res.status(500).json({ message: 'Internal server error' });
    }
};
