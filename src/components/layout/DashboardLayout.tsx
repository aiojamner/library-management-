import { useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '@/lib/auth';
import { Button } from '@/components/ui/button';
import {
  BookOpen,
  Users,
  CircleDollarSign,
  BarChart3,
  LogOut,
} from 'lucide-react';

export function DashboardLayout({ children }: { children: React.ReactNode }) {
  const { user, profile, signOut } = useAuth();
  const navigate = useNavigate();

  useEffect(() => {
    if (!user) {
      navigate('/auth');
    }
  }, [user, navigate]);

  const menuItems = [
    { icon: BookOpen, label: 'Books', path: '/dashboard/books' },
    { icon: Users, label: 'Users', path: '/dashboard/users' },
    { icon: CircleDollarSign, label: 'Fines', path: '/dashboard/fines' },
    { icon: BarChart3, label: 'Reports', path: '/dashboard/reports' },
  ];

  return (
    <div className="min-h-screen bg-background">
      <div className="flex">
        {/* Sidebar */}
        <div className="w-64 min-h-screen bg-card border-r">
          <div className="p-6">
            <h2 className="text-lg font-semibold">Library System</h2>
            <p className="text-sm text-muted-foreground">
              {profile?.first_name} {profile?.last_name}
            </p>
          </div>
          <nav className="space-y-2 px-4">
            {menuItems.map((item) => (
              <Button
                key={item.path}
                variant="ghost"
                className="w-full justify-start"
                onClick={() => navigate(item.path)}
              >
                <item.icon className="mr-2 h-4 w-4" />
                {item.label}
              </Button>
            ))}
          </nav>
          <div className="absolute bottom-4 px-4 w-64">
            <Button
              variant="ghost"
              className="w-full justify-start text-destructive"
              onClick={() => signOut()}
            >
              <LogOut className="mr-2 h-4 w-4" />
              Sign Out
            </Button>
          </div>
        </div>
        {/* Main Content */}
        <div className="flex-1 p-8">
          {children}
        </div>
      </div>
    </div>
  );
}