describe "seeds.rb" do
  it "creates 4 records in the spells table" do
    expect { load "db/seeds.rb" }.to change(Spell, :count).by(4)
  end
end
