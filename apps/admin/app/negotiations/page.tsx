'use client'

import { useState, useEffect } from 'react'
import { Card } from '@/app/components/ui/card'
import Badge from '@/app/components/ui/badge'
import Button from '@/app/components/ui/button'
import PageHeader from '@/app/components/page-header'
import { api } from '@/lib/api'

interface TradeMessage {
  id: string
  content: string
  messageType: string
  createdAt: string
  sender: {
    id: string
    email: string
    profile?: {
      displayName: string
    }
  }
  negotiation: {
    id: string
    trade: {
      id: string
      title: string
      owner: {
        id: string
        email: string
        profile?: {
          displayName: string
        }
      }
    }
    offer: {
      id: string
      bidder: {
        id: string
        email: string
        profile?: {
          displayName: string
        }
      }
    }
  }
}

interface Negotiation {
  id: string
  tradeId: string
  offerId: string
  createdAt: string
  trade: {
    id: string
    title: string
    status: string
    owner: {
      id: string
      email: string
      profile?: {
        displayName: string
      }
    }
  }
  offer: {
    id: string
    status: string
    amount?: number
    bidder: {
      id: string
      email: string
      profile?: {
        displayName: string
      }
    }
  }
  messages: TradeMessage[]
}

export default function NegotiationsPage() {
  const [negotiations, setNegotiations] = useState<Negotiation[]>([])
  const [messages, setMessages] = useState<TradeMessage[]>([])
  const [selectedNegotiation, setSelectedNegotiation] = useState<string | null>(null)
  const [loading, setLoading] = useState(true)
  const [messageStats, setMessageStats] = useState({
    total: 0,
    proposals: 0,
    acceptances: 0,
    declines: 0,
    disputes: 0
  })

  useEffect(() => {
    loadNegotiations()
    loadMessageStats()
  }, [])

  const loadNegotiations = async () => {
    try {
      // Note: This endpoint would need to be implemented in the backend
      const response = await api.get('/admin/negotiations')
      setNegotiations(response.data)
    } catch (error) {
      console.error('Error loading negotiations:', error)
    } finally {
      setLoading(false)
    }
  }

  const loadMessageStats = async () => {
    try {
      // Note: This endpoint would need to be implemented in the backend
      const response = await api.get('/admin/negotiations/stats')
      setMessageStats(response.data)
    } catch (error) {
      console.error('Error loading message stats:', error)
    }
  }

  const loadNegotiationMessages = async (negotiationId: string) => {
    try {
      // Note: This endpoint would need to be implemented in the backend
      const response = await api.get(`/admin/negotiations/${negotiationId}/messages`)
      setMessages(response.data)
      setSelectedNegotiation(negotiationId)
    } catch (error) {
      console.error('Error loading messages:', error)
    }
  }

  const getMessageTypeBadge = (messageType: string) => {
    const type = messageType.toLowerCase()
    switch (type) {
      case 'proposal':
        return <Badge color="blue">Proposal</Badge>
      case 'counter_offer':
        return <Badge color="blue">Counter Offer</Badge>
      case 'acceptance':
        return <Badge color="green">Accepted</Badge>
      case 'decline':
        return <Badge color="red">Declined</Badge>
      case 'dispute_report':
        return <Badge color="red">Dispute</Badge>
      case 'meeting_suggestion':
        return <Badge color="blue">Meeting</Badge>
      case 'schedule_suggestion':
        return <Badge color="blue">Schedule</Badge>
      default:
        return <Badge color="gray">Message</Badge>
    }
  }

  const getStatusBadge = (status: string) => {
    switch (status.toLowerCase()) {
      case 'open':
        return <Badge color="green">Open</Badge>
      case 'closed':
        return <Badge color="gray">Closed</Badge>
      case 'cancelled':
        return <Badge color="red">Cancelled</Badge>
      case 'pending':
        return <Badge color="blue">Pending</Badge>
      case 'accepted':
        return <Badge color="green">Accepted</Badge>
      case 'rejected':
        return <Badge color="red">Rejected</Badge>
      default:
        return <Badge color="gray">{status}</Badge>
    }
  }

  const formatUserName = (user: any) => {
    return user.profile?.displayName || user.email.split('@')[0]
  }

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleString()
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="text-lg">Loading negotiations...</div>
      </div>
    )
  }

  return (
    <div className="space-y-8">
      <PageHeader
        title="Negotiations Management"
        description="Monitor and manage trade negotiations, proposals, and disputes"
      />

      {/* Stats Cards */}
      <div className="grid grid-cols-1 md:grid-cols-5 gap-6">
        <Card className="p-6">
          <h3 className="text-sm font-medium text-gray-500">Total Messages</h3>
          <p className="text-2xl font-bold text-gray-900">{messageStats.total}</p>
        </Card>
        <Card className="p-6">
          <h3 className="text-sm font-medium text-gray-500">Proposals</h3>
          <p className="text-2xl font-bold text-blue-600">{messageStats.proposals}</p>
        </Card>
        <Card className="p-6">
          <h3 className="text-sm font-medium text-gray-500">Acceptances</h3>
          <p className="text-2xl font-bold text-green-600">{messageStats.acceptances}</p>
        </Card>
        <Card className="p-6">
          <h3 className="text-sm font-medium text-gray-500">Declines</h3>
          <p className="text-2xl font-bold text-red-600">{messageStats.declines}</p>
        </Card>
        <Card className="p-6">
          <h3 className="text-sm font-medium text-gray-500">Disputes</h3>
          <p className="text-2xl font-bold text-orange-600">{messageStats.disputes}</p>
        </Card>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
        {/* Negotiations List */}
        <Card className="p-6">
          <div className="flex items-center justify-between mb-6">
            <h2 className="text-xl font-semibold">Active Negotiations</h2>
            <Button onClick={loadNegotiations} variant="outline" size="sm">
              Refresh
            </Button>
          </div>
          
          <div className="space-y-4 max-h-96 overflow-y-auto">
            {negotiations.length === 0 ? (
              <p className="text-gray-500 text-center py-8">No active negotiations</p>
            ) : (
              negotiations.map((negotiation) => (
                <div
                  key={negotiation.id}
                  className={`p-4 border rounded-lg cursor-pointer transition-colors hover:bg-gray-50 ${
                    selectedNegotiation === negotiation.id ? 'border-blue-500 bg-blue-50' : 'border-gray-200'
                  }`}
                  onClick={() => loadNegotiationMessages(negotiation.id)}
                >
                  <div className="flex items-start justify-between mb-2">
                    <h3 className="font-medium text-gray-900 truncate">
                      {negotiation.trade.title}
                    </h3>
                    <div className="flex gap-2">
                      {getStatusBadge(negotiation.trade.status)}
                      {getStatusBadge(negotiation.offer.status)}
                    </div>
                  </div>
                  
                  <div className="text-sm text-gray-600 space-y-1">
                    <div className="flex justify-between">
                      <span>Owner: {formatUserName(negotiation.trade.owner)}</span>
                      <span>Bidder: {formatUserName(negotiation.offer.bidder)}</span>
                    </div>
                    <div className="flex justify-between items-center">
                      <span>{negotiation.messages.length} messages</span>
                      <span className="text-xs text-gray-400">
                        {formatDate(negotiation.createdAt)}
                      </span>
                    </div>
                    {negotiation.offer.amount && (
                      <div className="text-sm font-medium text-green-600">
                        Offer: {negotiation.offer.amount} BYC
                      </div>
                    )}
                  </div>
                </div>
              ))
            )}
          </div>
        </Card>

        {/* Messages Panel */}
        <Card className="p-6">
          <div className="flex items-center justify-between mb-6">
            <h2 className="text-xl font-semibold">Conversation</h2>
            {selectedNegotiation && (
              <Button
                onClick={() => setSelectedNegotiation(null)}
                variant="outline"
                size="sm"
              >
                Close
              </Button>
            )}
          </div>

          <div className="space-y-4 max-h-96 overflow-y-auto">
            {!selectedNegotiation ? (
              <p className="text-gray-500 text-center py-8">
                Select a negotiation to view messages
              </p>
            ) : messages.length === 0 ? (
              <p className="text-gray-500 text-center py-8">No messages found</p>
            ) : (
              messages.map((message) => (
                <div
                  key={message.id}
                  className="p-4 border border-gray-200 rounded-lg"
                >
                  <div className="flex items-start justify-between mb-2">
                    <div className="flex items-center gap-2">
                      <span className="font-medium text-gray-900">
                        {formatUserName(message.sender)}
                      </span>
                      {getMessageTypeBadge(message.messageType)}
                    </div>
                    <span className="text-xs text-gray-400">
                      {formatDate(message.createdAt)}
                    </span>
                  </div>

                  <p className="text-gray-700 mb-2">{message.content}</p>

                  {/* Special handling for disputes */}
                  {message.messageType === 'DISPUTE_REPORT' && (
                    <div className="mt-3 p-2 bg-red-50 border border-red-200 rounded">
                      <div className="flex items-center gap-2">
                        <span className="text-red-600 text-sm font-medium">
                          ⚠️ Dispute Reported
                        </span>
                      </div>
                      <p className="text-red-700 text-sm mt-1">
                        This negotiation requires admin attention
                      </p>
                    </div>
                  )}

                  {/* Special handling for proposals */}
                  {(message.messageType === 'PROPOSAL' || message.messageType === 'COUNTER_OFFER') && (
                    <div className="mt-3 p-2 bg-blue-50 border border-blue-200 rounded">
                      <span className="text-blue-600 text-sm font-medium">
                        💼 {message.messageType === 'COUNTER_OFFER' ? 'Counter Offer' : 'Proposal'} Details
                      </span>
                      <div className="text-blue-700 text-sm mt-1">
                        Trade: {message.negotiation.trade.title}
                      </div>
                    </div>
                  )}
                </div>
              ))
            )}
          </div>
        </Card>
      </div>
    </div>
  )
}