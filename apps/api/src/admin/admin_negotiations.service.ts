import { Injectable } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';
import { MessageType } from '@prisma/client';

@Injectable()
export class AdminNegotiationsService {
  constructor(private prisma: PrismaService) {}

  async listNegotiations() {
    return this.prisma.negotiation.findMany({
      include: {
        trade: {
          include: {
            owner: {
              include: {
                profile: true
              }
            }
          }
        },
        offer: {
          include: {
            bidder: {
              include: {
                profile: true
              }
            }
          }
        },
        messages: {
          orderBy: {
            createdAt: 'desc'
          },
          take: 1 // Get latest message for preview
        }
      },
      orderBy: {
        createdAt: 'desc'
      }
    });
  }

  async getNegotiationStats() {
    const [
      totalMessages,
      proposals,
      acceptances,
      declines,
      disputes
    ] = await Promise.all([
      this.prisma.negotiationMessage.count(),
      this.prisma.negotiationMessage.count({
        where: { messageType: MessageType.PROPOSAL }
      }),
      this.prisma.negotiationMessage.count({
        where: { messageType: MessageType.ACCEPTANCE }
      }),
      this.prisma.negotiationMessage.count({
        where: { messageType: MessageType.DECLINE }
      }),
      this.prisma.negotiationMessage.count({
        where: { messageType: MessageType.DISPUTE_REPORT }
      })
    ]);

    return {
      total: totalMessages,
      proposals,
      acceptances,
      declines,
      disputes
    };
  }

  async getNegotiationMessages(negotiationId: string) {
    return this.prisma.negotiationMessage.findMany({
      where: {
        negotiationId
      },
      include: {
        sender: {
          include: {
            profile: true
          }
        },
        negotiation: {
          include: {
            trade: {
              include: {
                owner: {
                  include: {
                    profile: true
                  }
                }
              }
            },
            offer: {
              include: {
                bidder: {
                  include: {
                    profile: true
                  }
                }
              }
            }
          }
        }
      },
      orderBy: {
        createdAt: 'asc'
      }
    });
  }

  async getActiveDisputes() {
    const disputeMessages = await this.prisma.negotiationMessage.findMany({
      where: {
        messageType: MessageType.DISPUTE_REPORT
      },
      include: {
        sender: {
          include: {
            profile: true
          }
        },
        negotiation: {
          include: {
            trade: {
              include: {
                owner: {
                  include: {
                    profile: true
                  }
                }
              }
            },
            offer: {
              include: {
                bidder: {
                  include: {
                    profile: true
                  }
                }
              }
            }
          }
        }
      },
      orderBy: {
        createdAt: 'desc'
      }
    });

    return disputeMessages;
  }

  async getRecentActivity() {
    const recentMessages = await this.prisma.negotiationMessage.findMany({
      take: 50,
      include: {
        sender: {
          include: {
            profile: true
          }
        },
        negotiation: {
          include: {
            trade: {
              include: {
                owner: {
                  include: {
                    profile: true
                  }
                }
              }
            },
            offer: {
              include: {
                bidder: {
                  include: {
                    profile: true
                  }
                }
              }
            }
          }
        }
      },
      orderBy: {
        createdAt: 'desc'
      }
    });

    // Group by activity type for dashboard insights
    const activityStats = {
      recentProposals: recentMessages.filter(m => 
        m.messageType === MessageType.PROPOSAL || 
        m.messageType === MessageType.COUNTER_OFFER
      ).length,
      recentAcceptances: recentMessages.filter(m => 
        m.messageType === MessageType.ACCEPTANCE
      ).length,
      recentDeclines: recentMessages.filter(m => 
        m.messageType === MessageType.DECLINE
      ).length,
      recentDisputes: recentMessages.filter(m => 
        m.messageType === MessageType.DISPUTE_REPORT
      ).length,
      totalRecentActivity: recentMessages.length
    };

    return {
      messages: recentMessages,
      stats: activityStats
    };
  }

  // Helper method for advanced analytics
  async getNegotiationAnalytics(days: number = 30) {
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - days);

    const analytics = await this.prisma.negotiationMessage.groupBy({
      by: ['messageType'],
      _count: {
        messageType: true
      },
      where: {
        createdAt: {
          gte: startDate
        }
      }
    });

    // Get success rate (acceptances vs total proposals)
    const [totalProposals, totalAcceptances] = await Promise.all([
      this.prisma.negotiationMessage.count({
        where: {
          messageType: {
            in: [MessageType.PROPOSAL, MessageType.COUNTER_OFFER]
          },
          createdAt: {
            gte: startDate
          }
        }
      }),
      this.prisma.negotiationMessage.count({
        where: {
          messageType: MessageType.ACCEPTANCE,
          createdAt: {
            gte: startDate
          }
        }
      })
    ]);

    const successRate = totalProposals > 0 ? (totalAcceptances / totalProposals) * 100 : 0;

    return {
      messageTypeBreakdown: analytics,
      successRate: Math.round(successRate * 100) / 100, // Round to 2 decimal places
      totalProposals,
      totalAcceptances,
      period: `${days} days`
    };
  }
}