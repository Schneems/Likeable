require 'spec_helper'
class CleanTestClassForLikeable
  include Likeable
  def like_key
    "like_key"
  end

  def to_hash(*args); {} end

  def foo
  end

  def id
    @id ||= rand(100)
  end
end




Likeable.setup do |like|
  like.find_one = lambda {|klass, id| klass.where(:id => id)}
end


describe Likeable do

  before(:each) do
    @user   = User.new
    @target = CleanTestClassForLikeable.new
  end
  describe 'instance methods' do

    describe "#add_like_from" do
      it "creates a like" do
        target_class = @target.class.to_s.downcase
        user_like_key = "users:like:#{@user.id}:#{target_class}"
        time = Time.now.to_f
        @user.should_receive(:like_key).with(target_class).and_return(user_like_key)
        Likeable.redis.should_receive(:hset).with("like_key", @user.id, time).once
        Likeable.redis.should_receive(:hset).with(user_like_key, @target.id, time).once
        @target.add_like_from(@user, time)
      end
    end

    describe "#remove_like_from" do
      it "removes a like" do
        target_class = @target.class.to_s.downcase
        user_like_key = "users:like:#{@user.id}:#{target_class}"
        @user.should_receive(:like_key).with(target_class).and_return(user_like_key)
        Likeable.redis.should_receive(:hdel).with("like_key", @user.id).once
        Likeable.redis.should_receive(:hdel).with(user_like_key, @target.id)
        @target.remove_like_from(@user)
      end
    end

    describe "#liked_users" do
      it "finds the users that like it" do
        @target.should_receive(:like_user_ids).and_return([1,2])
        User.should_receive(:where).with(:id => [1,2])
        @target.liked_users(@user)
      end
    end

    describe "#likes" do
      it "returns set of likes" do
        Likeable.redis.should_receive(:hkeys).with("like_key").once
        @target.like_user_ids
      end
    end

    describe "#liked_by?" do
      it "will answer if current user likes target" do
        Likeable.redis.should_receive(:hexists).with("like_key", @user.id).once
        @target.liked_by?(@user)
      end
    end

    describe "#liked_friend_ids" do
      it "will return all friend ids of user who like target" do
        common_value = 3
        @target.should_receive(:like_user_ids).and_return([1,2, common_value])
        @user.should_receive(:friend_ids).and_return([common_value])
        @target.liked_friend_ids(@user).should == [common_value]
      end
    end

    describe "#liked_friends" do
      it "will return all friends who like object" do
        values = [1]
        @target.should_receive(:liked_friend_ids).with(@user).and_return(values)
        User.should_receive(:where).with(:id => values)
        @target.liked_friends(@user)
      end
    end
  end

  describe "class methods" do
    describe 'after_like' do
      it 'should be a class method when included' do
        CleanTestClassForLikeable.respond_to?(:after_like).should be_true
      end
      it 'is called after a like is created' do
        CleanTestClassForLikeable.after_like(:foo)
        @target.should_receive(:foo)
        @target.add_like_from(@user)
      end
    end
  end

end
