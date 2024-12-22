import { BookList } from '@/components/dashboard/BookList';
import { UserProfile } from '@/components/dashboard/UserProfile';

export function DashboardPage() {
  return (
    <div className="space-y-6">
      <UserProfile />
      <BookList />
    </div>
  );
}