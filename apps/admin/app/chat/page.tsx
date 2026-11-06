'use client';

import { useState, useEffect } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from '../components/ui/card';
import { Button } from '../components/ui/button';
import { Input } from '../components/ui/input';
import { Badge } from '../components/ui/badge';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '../components/ui/tabs';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '../components/ui/table';
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from '../components/ui/dialog';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../components/ui/select';
import { Textarea } from '../components/ui/textarea';
import { toast } from '../components/ui/use-toast';
import { api } from '../lib/api';
import {
  Search,
  MessageSquare,
  AlertTriangle,
  Users,
  Ban,
  Eye,
  Trash2,
  CheckCircle,
  XCircle,
  Activity,
} from 'lucide-react';

interface Conversation {
  id: string;
  type: string;
  title?: string;
  participants: Array<{
    user: {
      id: string;
      email: string;
      profile: {
        displayName: string;
      };
    };
  }>;
  _count: {
    messages: number;
  };
  createdAt: string;
  isActive: boolean;
}

interface MessageReport {
  id: string;
  reason: string;
  description?: string;
  status: 'PENDING' | 'REVIEWED' | 'DISMISSED';
  adminNote?: string;
  createdAt: string;
  message: {
    id: string;
    content: string;
    sender: {
      id: string;
      email: string;
      profile: {
        displayName: string;
      };
    };
    conversation: {
      id: string;
      type: string;
      title?: string;
    };
  };
  reporter: {
    id: string;
    email: string;
    profile: {
      displayName: string;
    };
  };
}

interface ChatAnalytics {
  totalConversations: number;
  activeConversations: number;
  totalMessages: number;
  totalReports: number;
  pendingReports: number;
  bannedUsers: number;
}

export default function ChatModerationPage() {
  const [conversations, setConversations] = useState<Conversation[]>([]);
  const [reports, setReports] = useState<MessageReport[]>([]);
  const [analytics, setAnalytics] = useState<ChatAnalytics | null>(null);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedReport, setSelectedReport] = useState<MessageReport | null>(null);
  const [reportStatus, setReportStatus] = useState<string>('');
  const [adminNote, setAdminNote] = useState('');

  useEffect(() => {
    fetchData();
  }, []);

  const fetchData = async () => {
    try {
      setLoading(true);
      const [conversationsRes, reportsRes, analyticsRes] = await Promise.all([
        api.get('/admin/chat/conversations'),
        api.get('/admin/chat/reports'),
        api.get('/admin/chat/analytics/overview'),
      ]);

      setConversations(conversationsRes.data.conversations);
      setReports(reportsRes.data.reports);
      setAnalytics(analyticsRes.data);
    } catch (error) {
      console.error('Failed to fetch chat data:', error);
      toast({
        title: 'Error',
        description: 'Failed to load chat moderation data',
        variant: 'destructive',
      });
    } finally {
      setLoading(false);
    }
  };

  const handleReportAction = async (reportId: string, status: string, note?: string) => {
    try {
      await api.put(`/admin/chat/reports/${reportId}`, {
        status,
        adminNote: note,
      });

      await fetchData();
      setSelectedReport(null);
      toast({
        title: 'Success',
        description: 'Report updated successfully',
      });
    } catch (error) {
      console.error('Failed to update report:', error);
      toast({
        title: 'Error',
        description: 'Failed to update report',
        variant: 'destructive',
      });
    }
  };

  const handleDeleteMessage = async (messageId: string) => {
    try {
      await api.delete(`/admin/chat/messages/${messageId}`);
      await fetchData();
      toast({
        title: 'Success',
        description: 'Message deleted successfully',
      });
    } catch (error) {
      console.error('Failed to delete message:', error);
      toast({
        title: 'Error',
        description: 'Failed to delete message',
        variant: 'destructive',
      });
    }
  };

  const handleBanUser = async (userId: string) => {
    try {
      const reason = prompt('Reason for chat ban:');
      if (!reason) return;

      await api.post(`/admin/chat/users/${userId}/ban`, {
        reason,
        duration: null, // Permanent ban
      });

      await fetchData();
      toast({
        title: 'Success',
        description: 'User banned from chat',
      });
    } catch (error) {
      console.error('Failed to ban user:', error);
      toast({
        title: 'Error',
        description: 'Failed to ban user',
        variant: 'destructive',
      });
    }
  };

  const handleDeactivateConversation = async (conversationId: string) => {
    try {
      await api.delete(`/admin/chat/conversations/${conversationId}`);
      await fetchData();
      toast({
        title: 'Success',
        description: 'Conversation deactivated',
      });
    } catch (error) {
      console.error('Failed to deactivate conversation:', error);
      toast({
        title: 'Error',
        description: 'Failed to deactivate conversation',
        variant: 'destructive',
      });
    }
  };

  const getStatusBadge = (status: string) => {
    switch (status) {
      case 'PENDING':
        return <Badge variant="destructive">Pending</Badge>;
      case 'REVIEWED':
        return <Badge variant="default">Reviewed</Badge>;
      case 'DISMISSED':
        return <Badge variant="secondary">Dismissed</Badge>;
      default:
        return <Badge variant="outline">{status}</Badge>;
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-96">
        <div className="text-lg">Loading chat moderation data...</div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h1 className="text-2xl font-bold">Chat Moderation</h1>
        <div className="flex items-center space-x-2">
          <Input
            placeholder="Search conversations, users..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="w-64"
          />
          <Button variant="outline" size="icon">
            <Search className="h-4 w-4" />
          </Button>
        </div>
      </div>

      {/* Analytics Overview */}
      {analytics && (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          <Card>
            <CardContent className="pt-6">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm text-muted-foreground">Total Conversations</p>
                  <p className="text-2xl font-bold">{analytics.totalConversations}</p>
                </div>
                <MessageSquare className="h-8 w-8 text-blue-500" />
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardContent className="pt-6">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm text-muted-foreground">Active Conversations</p>
                  <p className="text-2xl font-bold">{analytics.activeConversations}</p>
                </div>
                <Activity className="h-8 w-8 text-green-500" />
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardContent className="pt-6">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm text-muted-foreground">Pending Reports</p>
                  <p className="text-2xl font-bold">{analytics.pendingReports}</p>
                </div>
                <AlertTriangle className="h-8 w-8 text-yellow-500" />
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardContent className="pt-6">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm text-muted-foreground">Banned Users</p>
                  <p className="text-2xl font-bold">{analytics.bannedUsers}</p>
                </div>
                <Ban className="h-8 w-8 text-red-500" />
              </div>
            </CardContent>
          </Card>
        </div>
      )}

      <Tabs defaultValue="reports" className="space-y-4">
        <TabsList>
          <TabsTrigger value="reports">Message Reports</TabsTrigger>
          <TabsTrigger value="conversations">Conversations</TabsTrigger>
        </TabsList>

        <TabsContent value="reports" className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle>Message Reports</CardTitle>
            </CardHeader>
            <CardContent>
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Reporter</TableHead>
                    <TableHead>Message</TableHead>
                    <TableHead>Sender</TableHead>
                    <TableHead>Reason</TableHead>
                    <TableHead>Status</TableHead>
                    <TableHead>Date</TableHead>
                    <TableHead>Actions</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {reports.map((report) => (
                    <TableRow key={report.id}>
                      <TableCell>{report.reporter.profile.displayName}</TableCell>
                      <TableCell className="max-w-md truncate">
                        {report.message.content}
                      </TableCell>
                      <TableCell>{report.message.sender.profile.displayName}</TableCell>
                      <TableCell>
                        <Badge variant="outline">{report.reason}</Badge>
                      </TableCell>
                      <TableCell>{getStatusBadge(report.status)}</TableCell>
                      <TableCell>
                        {new Date(report.createdAt).toLocaleDateString()}
                      </TableCell>
                      <TableCell>
                        <div className="flex space-x-2">
                          <Dialog>
                            <DialogTrigger asChild>
                              <Button
                                variant="outline"
                                size="sm"
                                onClick={() => setSelectedReport(report)}
                              >
                                <Eye className="h-4 w-4" />
                              </Button>
                            </DialogTrigger>
                            <DialogContent className="max-w-2xl">
                              <DialogHeader>
                                <DialogTitle>Message Report Details</DialogTitle>
                              </DialogHeader>
                              {selectedReport && (
                                <div className="space-y-4">
                                  <div>
                                    <label className="text-sm font-medium">Message Content:</label>
                                    <p className="mt-1 p-3 bg-muted rounded-md">
                                      {selectedReport.message.content}
                                    </p>
                                  </div>
                                  
                                  <div className="grid grid-cols-2 gap-4">
                                    <div>
                                      <label className="text-sm font-medium">Sender:</label>
                                      <p>{selectedReport.message.sender.profile.displayName}</p>
                                    </div>
                                    <div>
                                      <label className="text-sm font-medium">Reporter:</label>
                                      <p>{selectedReport.reporter.profile.displayName}</p>
                                    </div>
                                  </div>

                                  <div>
                                    <label className="text-sm font-medium">Report Reason:</label>
                                    <p>{selectedReport.reason}</p>
                                  </div>

                                  {selectedReport.description && (
                                    <div>
                                      <label className="text-sm font-medium">Description:</label>
                                      <p>{selectedReport.description}</p>
                                    </div>
                                  )}

                                  <div className="space-y-2">
                                    <label className="text-sm font-medium">Admin Action:</label>
                                    <Select
                                      value={reportStatus}
                                      onValueChange={setReportStatus}
                                    >
                                      <SelectTrigger>
                                        <SelectValue placeholder="Select action" />
                                      </SelectTrigger>
                                      <SelectContent>
                                        <SelectItem value="REVIEWED">Mark as Reviewed</SelectItem>
                                        <SelectItem value="DISMISSED">Dismiss Report</SelectItem>
                                      </SelectContent>
                                    </Select>
                                  </div>

                                  <div className="space-y-2">
                                    <label className="text-sm font-medium">Admin Note (Optional):</label>
                                    <Textarea
                                      value={adminNote}
                                      onChange={(e) => setAdminNote(e.target.value)}
                                      placeholder="Add notes about this report..."
                                    />
                                  </div>

                                  <div className="flex justify-between">
                                    <div className="space-x-2">
                                      <Button
                                        variant="destructive"
                                        onClick={() => handleDeleteMessage(selectedReport.message.id)}
                                      >
                                        <Trash2 className="h-4 w-4 mr-2" />
                                        Delete Message
                                      </Button>
                                      <Button
                                        variant="outline"
                                        onClick={() => handleBanUser(selectedReport.message.sender.id)}
                                      >
                                        <Ban className="h-4 w-4 mr-2" />
                                        Ban User
                                      </Button>
                                    </div>
                                    <Button
                                      onClick={() => handleReportAction(selectedReport.id, reportStatus, adminNote)}
                                      disabled={!reportStatus}
                                    >
                                      Update Report
                                    </Button>
                                  </div>
                                </div>
                              )}
                            </DialogContent>
                          </Dialog>
                        </div>
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="conversations" className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle>All Conversations</CardTitle>
            </CardHeader>
            <CardContent>
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Type</TableHead>
                    <TableHead>Title/Participants</TableHead>
                    <TableHead>Messages</TableHead>
                    <TableHead>Created</TableHead>
                    <TableHead>Status</TableHead>
                    <TableHead>Actions</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {conversations.map((conversation) => (
                    <TableRow key={conversation.id}>
                      <TableCell>
                        <Badge variant="outline">{conversation.type}</Badge>
                      </TableCell>
                      <TableCell>
                        {conversation.title || 
                          conversation.participants.map(p => p.user.profile.displayName).join(', ')}
                      </TableCell>
                      <TableCell>{conversation._count.messages}</TableCell>
                      <TableCell>
                        {new Date(conversation.createdAt).toLocaleDateString()}
                      </TableCell>
                      <TableCell>
                        {conversation.isActive ? (
                          <Badge variant="default">Active</Badge>
                        ) : (
                          <Badge variant="secondary">Inactive</Badge>
                        )}
                      </TableCell>
                      <TableCell>
                        <Button
                          variant="outline"
                          size="sm"
                          onClick={() => handleDeactivateConversation(conversation.id)}
                          disabled={!conversation.isActive}
                        >
                          Deactivate
                        </Button>
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>
    </div>
  );
}