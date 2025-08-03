import { useState } from "react";
import { mockPosts } from "../mocks/post";

const PostsTable = () => {
  const [posts, setPosts] = useState(mockPosts);
  const [editingPostId, setEditingPostId] = useState<number | null>(null);
  const [editContent, setEditContent] = useState("");

  const handleDelete = (id: number) => {
    setPosts(posts.filter((post) => post.id !== id));
  };

  const handleEdit = (id: number, content: string) => {
    setEditingPostId(id);
    setEditContent(content);
  };

  const handleSave = (id: number) => {
    setPosts(posts.map((post) => post.id === id ? { ...post, content: editContent } : post));
    setEditingPostId(null);
  };

  const handleAdd = () => {
    const newPost = {
      id: posts.length + 1,
      title: "New Post",
      content: "Write your content...",
      author: "Admin",
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };
    setPosts([newPost, ...posts]);
  };

  return (
    <div className="p-4 space-y-4">
      <div className="flex justify-between items-center">
        <h1 className="text-2xl font-bold">Manage Posts</h1>
        <button onClick={handleAdd} className="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700">Add Post</button>
      </div>

      <table className="w-full text-sm border">
        <thead className="bg-gray-100 text-left">
          <tr>
            <th className="p-2">Title</th>
            <th className="p-2">Content</th>
            <th className="p-2">Author</th>
            <th className="p-2">Actions</th>
          </tr>
        </thead>
        <tbody>
          {posts.map(post => (
            <tr key={post.id} className="border-t">
              <td className="p-2 font-medium">{post.title}</td>
              <td className="p-2">
                {editingPostId === post.id ? (
                  <textarea
                    className="w-full p-1 border rounded"
                    value={editContent}
                    onChange={(e) => setEditContent(e.target.value)}
                  />
                ) : (
                  post.content
                )}
              </td>
              <td className="p-2">{post.author}</td>
              <td className="p-2 flex space-x-2">
                {editingPostId === post.id ? (
                  <button onClick={() => handleSave(post.id)} className="text-green-600">Save</button>
                ) : (
                  <button onClick={() => handleEdit(post.id, post.content)} className="text-blue-600">Edit</button>
                )}
                <button onClick={() => handleDelete(post.id)} className="text-red-600">Delete</button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
};

export default PostsTable;