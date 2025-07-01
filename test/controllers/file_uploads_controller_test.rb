require "test_helper"

class MonthlyStatementsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @monthly_statement = monthly_statements(:one)
  end

  test "should get index" do
    get monthly_statements_url, as: :json
    assert_response :success
  end

  test "should create monthly_statement" do
    assert_difference("MonthlyStatement.count") do
      post monthly_statements_url, params: { monthly_statement: { file: @monthly_statement.file, status: @monthly_statement.status, uploaded_at: @monthly_statement.uploaded_at } }, as: :json
    end

    assert_response :created
  end

  test "should show monthly_statement" do
    get monthly_statement_url(@monthly_statement), as: :json
    assert_response :success
  end

  test "should update monthly_statement" do
    patch monthly_statement_url(@monthly_statement), params: { monthly_statement: { file: @monthly_statement.file, status: @monthly_statement.status, uploaded_at: @monthly_statement.uploaded_at } }, as: :json
    assert_response :success
  end

  test "should destroy monthly_statement" do
    assert_difference("MonthlyStatement.count", -1) do
      delete monthly_statement_url(@monthly_statement), as: :json
    end

    assert_response :no_content
  end
end
